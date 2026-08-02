#!/usr/bin/env bash
#
# End-to-end run: the whole product, locally, with nothing reaching production.
#
#   Firebase emulators (auth + firestore)  ← the only storage and identity
#     └─ Nitro dev server on :3000         ← the real backend, with a stubbed scan
#          └─ iPhone simulator             ← the real app, driven by XCUITest
#
# Everything starts empty and is thrown away at the end, so the run needs no
# reset endpoint, no test account in the cloud project, and costs no AI quota.
#
# Usage: scripts/e2e.sh
#
# Requires: bun, Xcode, and a JDK (the Firestore emulator runs on the JVM).
#
set -euo pipefail

# Absolute, because the second phase is re-entered by `emulators:exec`, which
# runs the command through a shell of its own.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$SELF")/.."

NITRO_PORT=3000
AUTH_PORT=9099
FIRESTORE_PORT=8080
# No OS pinned: xcodebuild picks the newest runtime installed, which keeps the
# same command working on the dev Mac and on the CI image.
DESTINATION="${E2E_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
# The scenarios that gate a release, space-separated. They share one emulator
# run: each test signs in with an account of its own, so they stay isolated.
TESTS="${E2E_TESTS:-VinariumUITests/CellarFlowTest VinariumUITests/FavoriteFlowTest VinariumUITests/GiveAsGiftFlowTest VinariumUITests/RecommendationFlowTest}"

# The Firestore emulator runs on the JVM. Homebrew's openjdk is keg-only, so it
# is not on the PATH unless the shell profile puts it there — find it rather than
# asking every developer to edit their profile.
# Note the `java -version` probe rather than `command -v java`: macOS ships a
# /usr/bin/java stub that exists but only prints "Unable to locate a Java Runtime".
if ! java -version >/dev/null 2>&1; then
  for candidate in /opt/homebrew/opt/openjdk/bin /usr/local/opt/openjdk/bin; do
    if [ -x "$candidate/java" ]; then
      export PATH="$candidate:$PATH"
      break
    fi
  done
fi
if ! java -version >/dev/null 2>&1; then
  echo "error: the Firestore emulator needs a JDK — 'brew install openjdk'." >&2
  exit 1
fi

# xcode-select points at CommandLineTools on the dev Mac; CI sets this already.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# The emulators must run under the project the app is built against: a Firebase
# ID token carries its project as audience, and verifyIdToken rejects any other.
PLIST=ios/Vinarium/GoogleService-Info.plist
if [ ! -f "$PLIST" ]; then
  echo "error: $PLIST is missing — it is gitignored, copy it from the Firebase console." >&2
  exit 1
fi
PROJECT_ID=$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "$PLIST")

# Second phase: runs inside `emulators:exec`, with the emulators up.
if [ "${1:-}" = "--inner" ]; then
  # Fail-fast guard, deliberately redundant with the exports below. Without
  # these two, firebase-admin talks to the real project: the server would write
  # test bottles into production Firestore.
  : "${FIRESTORE_EMULATOR_HOST:?refusing to start: the Firestore emulator host is unset}"
  : "${FIREBASE_AUTH_EMULATOR_HOST:?refusing to start: the Auth emulator host is unset}"

  # Nitro silently moves to the next free port when :3000 is taken, and the app
  # would then talk to whatever already sits there. Better to stop.
  if lsof -ti "tcp:$NITRO_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "error: something already listens on :$NITRO_PORT — stop it and retry." >&2
    exit 1
  fi

  SERVER_LOG=$(mktemp -t vinarium-e2e-server)
  echo "==> Starting the Nitro server on :$NITRO_PORT (log: $SERVER_LOG)"
  # Job control gives the server its own process group, so the whole tree can be
  # signalled at once. `bun run dev` spawns nitro, which spawns a worker: killing
  # the parent alone leaves a listener holding :3000 for the next run.
  set -m
  bun run dev >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  set +m
  # shellcheck disable=SC2317  # called through the trap
  cleanup() {
    kill -TERM -"$SERVER_PID" 2>/dev/null || kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  }
  trap cleanup EXIT

  for _ in $(seq 60); do
    if curl -fsS "http://127.0.0.1:$NITRO_PORT/app-config" >/dev/null 2>&1; then break; fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "error: the server died on startup" >&2
      cat "$SERVER_LOG" >&2
      exit 1
    fi
    sleep 1
  done
  if ! curl -fsS "http://127.0.0.1:$NITRO_PORT/app-config" >/dev/null 2>&1; then
    echo "error: the server never answered on :$NITRO_PORT" >&2
    cat "$SERVER_LOG" >&2
    exit 1
  fi

  echo "==> Running $TESTS on $DESTINATION"
  # Two retries. Every CI failure so far landed on a different step — a tap that
  # missed, a sheet that had not settled — while the server answered every single
  # request under 3s (the dev request log below proves it), and the same run is
  # green locally. That is the simulator being slow, not the product being wrong.
  # A scenario that fails three times in a row is a real failure.
  #
  # Signing stays on, unlike the compile-only CI job: a simulator build signs
  # ad-hoc with no certificate, and without it the app gets no entitlements —
  # Firebase Auth then fails every keychain write with -34018 and never signs in.
  ONLY_TESTING=()
  for target in $TESTS; do ONLY_TESTING+=("-only-testing:$target"); done

  set +e
  xcodebuild test \
    -project ios/Vinarium.xcodeproj \
    -scheme Vinarium \
    -destination "$DESTINATION" \
    "${ONLY_TESTING[@]}" \
    -resultBundlePath build/e2e.xcresult \
    -retry-tests-on-failure -test-iterations 3
  STATUS=$?
  set -e

  if [ $STATUS -ne 0 ]; then
    echo "==> Tests failed — last 200 lines of the server log:" >&2
    # The server logs one line per request in dev, so this is the record of what
    # the app actually asked for and how long each answer took.
    tail -200 "$SERVER_LOG" >&2
  fi
  exit $STATUS
fi

# First phase: bring the emulators up, then re-enter this script.
# A previous run still shutting down holds these ports, and the emulators fail
# with a bare "port taken" halfway through — check up front instead.
for port in "$AUTH_PORT" "$FIRESTORE_PORT" "$NITRO_PORT"; do
  if lsof -ti "tcp:$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "error: port $port is already in use — a previous run may still be shutting down." >&2
    exit 1
  fi
done

echo "==> Starting the Firebase emulators for project $PROJECT_ID"
rm -rf build/e2e.xcresult

export GCLOUD_PROJECT="$PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export FIRESTORE_EMULATOR_HOST="127.0.0.1:$FIRESTORE_PORT"
export FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:$AUTH_PORT"
# The scan answers with a fixed label instead of calling Gemini: the models cost
# money, take seconds, and never answer twice the same.
export NITRO_SCAN_STUB=1
export NITRO_GOOGLE_API_KEY=stub
export NITRO_ADMIN_TOKEN=stub
# The dev auth bypass must stay off: the app sends a real emulator token, and a
# blank bypass would hide a broken sign-in behind a working test.
export NITRO_DEV_USER_ID=

exec bunx firebase-tools emulators:exec \
  --only "auth,firestore" \
  --project "$PROJECT_ID" \
  "$SELF --inner"
