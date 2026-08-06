#!/usr/bin/env bash
#
# Captures the app's screens, from a cellar seeded for the occasion.
#
#   Firebase emulators + Nitro on :3000     ← scripts/e2e.sh brings these up
#     └─ seed-screenshot-cellar.ts          ← fills one fixed account
#          └─ ScreenshotTest on the simulator
#
# Nothing reaches production: the same local stack as the end-to-end gate, with
# a stubbed scan and emulator identities.
#
#   scripts/screenshots.sh              # French, into screenshots/ (the README)
#   scripts/screenshots.sh fr en de     # one run per language, into screenshots/<lang>/
#   scripts/screenshots.sh all          # every App Store language
#
# The first form is the one the README needs; the others feed
# generate-appstore-previews.ts.
set -euo pipefail

cd "$(dirname "$0")/.."

ALL_LANGUAGES=(fr en de es it pt ja)

case "${1:-fr}" in
  all) LANGUAGES=("${ALL_LANGUAGES[@]}") ;;
  *) LANGUAGES=("$@") ;;
esac
[ ${#LANGUAGES[@]} -eq 0 ] && LANGUAGES=(fr)

mkdir -p build

for language in "${LANGUAGES[@]}"; do
  # French always lands at the root: that is where the README reads it from, and
  # where generate-appstore-previews.ts looks for it. Where a language lands
  # must not depend on how the script was called. The test derives the same rule
  # from the language, so it is stated once on each side and nowhere in between.
  if [ "$language" = "fr" ]; then
    destination="screenshots/"
  else
    destination="screenshots/$language/"
  fi

  # Handed over as a file, not as an environment variable: `TEST_RUNNER_<NAME>`
  # on the xcodebuild command line does not reach the test process here, and the
  # run came out in the default language while claiming to be another — silently
  # overwriting the captures it should have sat beside.
  echo "$language" > build/screenshot-language

  echo "==> Capturing $language into $destination"
  E2E_TESTS="VinariumUITests/ScreenshotTest" \
  E2E_SEED="bun scripts/seed-screenshot-cellar.ts" \
    scripts/e2e.sh

  # The test writes the files itself, so a green run that produced nothing is a
  # real failure — and one that hides the language it actually captured.
  if [ "$(ls -1 "$destination"*.png 2>/dev/null | wc -l | tr -d ' ')" -lt 7 ]; then
    echo "error: $destination holds fewer than the seven expected captures." >&2
    exit 1
  fi
  echo "==> $destination"
  ls -1 "$destination"*.png
done
