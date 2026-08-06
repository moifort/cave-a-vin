# Vinarium - Project Directives

## Language

Everything versioned and technical is written in **English**: commit messages, code, code comments, and documentation (README, this file). This now includes `CHANGELOG.md`, which is the **English source of truth**. The **only** non-English prose in the repo is user-facing copy: the served changelog translations (`CHANGELOG.fr.md`, `CHANGELOG.de.md`, `CHANGELOG.es.md`, `CHANGELOG.it.md`, `CHANGELOG.pt.md`, `CHANGELOG.ja.md`) and the iOS app's on-screen text (the `Localizable.xcstrings` String Catalog). Never mix languages in a commit message or a comment.

The changelog lives in one file per served language, each organized newest-version-first: `CHANGELOG.md` (English, the source of truth) plus one translation per App Store market (`CHANGELOG.fr.md`, `CHANGELOG.de.md`, `CHANGELOG.es.md`, `CHANGELOG.it.md`, `CHANGELOG.pt.md`, `CHANGELOG.ja.md`), all kept in lockstep. `generate:assets` bundles them into `server/system/changelog-content.ts` as a per-language map, and the `changelog` GraphQL query serves the caller's language from `Accept-Language` (English fallback). Each version heading carries the App Store version **and** its release date: `## 1.1 (2026.07.15)` (a plain `## Unreleased`, no date, is allowed for pending work). The app shows the version as the row title and formats the date on the right. Under each version, three sub-sections (only those that have content), mirrored across languages: English uses `### New` / `### Fixes` / `### Performance`, French `### Nouveautés` / `### Corrections` / `### Performance`, and the other languages their natural equivalents. Only log **consequential** changes — cosmetic tweaks (renaming a label, changing a subtitle, dropping a counter) have no impact and are excluded. Note: the server parser only reads `## ` headings and bullets, so `###` sub-headings are ignored and the app renders a flat list — the sections are organizational for the repo.

**Tone of the notes** (both files). Write each bullet as a plain, impersonal statement of what was put in place. Do **not** address the reader: no "you" in English, no `vous`/`tu` in French, and the equivalent impersonal register in every other language. Prefer "The cellar's size can now be changed from Settings" over "You can now change your cellar's size". Use flowing, complete sentences with normal punctuation, and go straight to the essential: cut filler ("at any time", "simply", "à tout moment", "également"). **Never use an em-dash or en-dash (`—`, `–`) in the copy** — it reads as machine-written; reword, or use a period, comma, or colon. These rules are about the user-facing changelog copy, not this instruction file.

## Build & Verification Commands

- **Backend typecheck**: `bun tsc --noEmit`
- **Regenerate types** (if routes changed): `bunx nitro prepare` (run before `bun tsc`)
- **iOS build**:
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ios/Vinarium.xcodeproj -scheme Vinarium -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
  ```
- **Unit tests**: `bun test`
- **Test coverage**: `bun test --coverage`
- **End-to-end**: `./scripts/e2e.sh` (Firebase emulators + Nitro + iPhone simulator, nothing touches production — see [docs/e2e.md](docs/e2e.md)). Needs a JDK for the Firestore emulator.
- **Screenshots**: `./scripts/screenshots.sh [all|<lang>…]` — same local stack, on a cellar seeded for the occasion; feeds both the README and the App Store panels (see [docs/screenshots.md](docs/screenshots.md)).
- **Linter**: `bunx biome check`
- **Runtime**: always use `bun`/`bunx`, never `npm`/`npx`
- **GraphQL codegen** (if the schema changed): `bun run generate:graphql` (regenerates `shared/schema.graphql`), then `cd ios && apollo-ios-cli generate` (config `ios/apollo-codegen-config.json`)

## Collaboration

- **Work inline, never through subagents**: exploration, review, debugging and planning all happen in the main conversation — never `Task`/`Agent`, never a parallel-worker or subagent-driven skill, plan mode included.

## Development Workflow

1. Always verify the build before committing (backend `bun tsc --noEmit` + `xcodebuild` depending on what was touched)
2. Run `bunx nitro prepare` before `bun tsc` if routes were added/modified
3. After each completed task: run an expert code review (`superpowers:requesting-code-review`) before committing
4. **Commit freely**: group and commit changes as you see fit without asking the user — don't ask about grouping, you decide.
5. **Never push until the user explicitly says "push".** Commits accumulate locally; pushing is user-gated.

### Push protocol (only when the user says "push")

Before pushing, update the user-facing surfaces, then push:

1. **README** (`README.md`): update the Features list / Tech Stack if the pushed work changed them.
2. **README previews** (`screenshots/*.png`): regenerate them with `scripts/screenshots.sh` if the touched UI changed visually (the App Store panels follow with `bun scripts/generate-appstore-previews.ts` — see [docs/screenshots.md](docs/screenshots.md)).
3. **iOS GraphQL API** (if the GraphQL schema changed): run `bun run generate:graphql`, then `cd ios && apollo-ios-cli generate`, and commit the regenerated `shared/schema.graphql` and `ios/Vinarium/Generated/GraphQL/` so the app's typed operations stay in sync with the deployed schema.
4. **Linter**: run `bun run lint:fix` (`biome check --write`) and commit what it fixes. CI is not a linter — a lint error must never be discovered from a red pipeline. Biome scans the whole repo, `ios/` included; when it flags a **generated** artifact, exclude it in `biome.json` rather than let the linter reformat it.
5. Push.

**Not at push time — the changelog.** Do **not** touch any `CHANGELOG*.md` when pushing. The changelog is written only at the moment of an iOS App Store release, as part of the release flow (see [App Store Distribution](#app-store-distribution)) — a normal `main` push carries no changelog change.

## Skills

- Use the `swiftui-expert-skill` skill for all SwiftUI code
- Use the `nitro-backend` skill for all backend Nitro/H3 code
- Use the `superpowers:requesting-code-review` skill for all code reviews

## Backend Patterns (TypeScript/Nitro)

Patterns live in `docs/`; the essentials:

- **Domain architecture** — `server/domain/{domain}/` with `types.ts`, `primitives.ts`, `command.ts` (`XxxCommand` namespace), `query.ts` (`XxxQuery` namespace), optional `business-rules.ts` / `use-case.ts`, and `infrastructure/{repository.ts, graphql/}`. Repositories are bare functions (`import * as repository`), private to the domain. See [docs/architecture.md](docs/architecture.md) and [docs/domain-guide.md](docs/domain-guide.md).
- **Branded types** — `ts-brand` + Zod constructors in `primitives.ts`; one GraphQL scalar per brand. See [docs/branded-types.md](docs/branded-types.md).
- **Errors** — commands return bare string-literal outcomes (`'not-found' as const`) or the domain value; resolvers map them with `match().exhaustive()` + `notFound`/`badUserInput` helpers. `throw` for impossible states. See [docs/error-handling.md](docs/error-handling.md).
- **Storage** — native Firestore (`firebase-admin`) via `db()` from `server/system/firebase.ts`, only inside `infrastructure/repository.ts`. Helpers in `server/utils/firestore.ts` (`genericDataConverter`, `atomically`, `deleteInBatches`, `bulkSave`, `userBeverageRecordRepository`). See [docs/architecture.md](docs/architecture.md#storage).
- **GraphQL** — Apollo Server + Pothos, single endpoint `POST /graphql`. The schema is not versioned: breaking schema changes ride the force-update gate (bump `MINIMUM_SUPPORTED_IOS_BUILD`, ship backend + iOS together) — see [docs/api-evolution.md](docs/api-evolution.md). Nested `Beverage` satellite fields must never scan a collection or read one doc per parent row (N+1) — they resolve through the per-request loaders in `server/domain/shared/graphql/loaders.ts`. See [docs/api-patterns.md](docs/api-patterns.md).
- **Naming** — function names carry the business concept, not the technical pattern. The name IS the rule or action. See [docs/code-style.md](docs/code-style.md).
- **Observability** — never `console.*`; log via `createLogger(tag)` from `server/system/logger.ts` (consola). Sentry (error capture + domain-namespace tracing) activates only in a built (non-dev) bundle **and** only when `NITRO_SENTRY_DSN` is set, mirroring the iOS `#if DEBUG` gate — a local `bun run dev` never reports. See `server/plugins/00-sentry.ts` and `server/system/sentry/`.
- **Tests** — `bun:test`, three suffixes: `*.unit.test.ts` (pure functions/primitives), `*.int.test.ts` (commands/queries against the fake Firestore), `*.feat.test.ts` (GraphQL against the schema). Mock via `mock.module('~/system/firebase', () => ({ db: fakeDb }))`; assert read budgets with the split `fake.docReads`/`fake.queryReads`, not the combined `fake.reads`. Optional BDD DSL in `server/test/bdd.ts`. See [docs/domain-guide.md](docs/domain-guide.md#tests).
- **Formatter** — Biome (spaces, single quotes, no semicolons, line width 100).

## Database Migrations

- Location: `server/system/migration/`
- Forward-only sequential migrations, no rollback
- Meta tracked in the Firestore collection `migration-meta` (doc `state`)
- Triggered by `POST /admin/migrate` (`server/routes/admin/migrate.post.ts`), called by `scripts/bootstrap.sh` during provisioning — no boot-time plugin
- To add a migration: create `server/system/migration/migrations/NNNN-name.ts`, register in `migrations/index.ts`
- Migration `version` uses branded `MigrationVersion` (starts at 1, version 0 is reserved sentinel)
- Migrations receive a `MigrationContext` with the Firestore `db`, return `MigrationResult`
- Runner wraps each migration in try/catch — migrations don't need their own error handling
- **When to migrate**: renaming a field, changing a field's structure, changing enum values, removing stale data
- **No migration needed**: adding a new optional (`?`) field, adding a new collection, changing query logic/routes

Full guide (writing/testing a migration): [docs/migrations.md](docs/migrations.md).

## iOS Patterns (SwiftUI)

- Target: iOS 26.0, Swift 6 (strict concurrency); `@MainActor` on ViewModels, `Sendable` on model types.
- Feature structure `ios/Vinarium/Features/{Feature}/` with the coordinator `{Feature}View.swift` at the root and `components/{pages,organisms,molecules}` below; cross-feature atoms in `ios/Vinarium/Shared/Components/`. The feature-root `*View` is the coordinator (owns the ViewModel, navigation, sheets, domain→primitive mapping); the `*Page` is pure and previewable. Primitive-first leaf views, organisms as mapping boundaries, previews as storybook. See [docs/ios-guide.md](docs/ios-guide.md).
- GraphQL over Apollo iOS (`GraphQLClient` singleton, Firebase Bearer auth); `.graphql` operations in `Features/{Feature}/GraphQL/`, generated types in `Generated/GraphQL/` (namespace `VinariumGraphQL`).
- Xcode uses `fileSystemSynchronizedGroups` (no need to manually add files). `DEVELOPER_DIR` required because `xcode-select` points to CommandLineTools.

## App Store Distribution

Full checklist in `ios/APP_STORE_SUBMISSION.md`. Build with the latest **final** Xcode (currently 26.6 / `17F113`, SDK `23F81a`) — never a beta/RC Xcode, and never an older release once a newer final ships. Both trigger **ITMS-90111** (Unsupported SDK or Xcode version) on upload.

**Automated release flow** (full procedure in `ios/APP_STORE_SUBMISSION.md`), in order:
1. Write the release notes in English under `## Unreleased` in `CHANGELOG.md`, then the translation under `## Unreleased` in **each** served language (`CHANGELOG.fr.md`, `CHANGELOG.de.md`, `CHANGELOG.es.md`, `CHANGELOG.it.md`, `CHANGELOG.pt.md`, `CHANGELOG.ja.md`). Rename the `## Unreleased` heading in **every** file to `## <version> (<YYYY.MM.DD>)` (e.g. `## 1.2 (2026.08.01)`) — matching the version you are about to tag. There is no CI date-stamp; versioning is manual.
2. **Get the French notes validated** — before any push, show the user the **French** release notes (`CHANGELOG.fr.md`, the version block just written) in the conversation and wait for their explicit approval. They are the reference reader for the copy: apply their corrections, mirror them across the other languages, and re-submit until they say it's good. No push happens on unvalidated notes.
3. **Push `main`** — `deploy.yml` deploys the backend and regenerates the served changelog asset from all the `CHANGELOG.*.md` files. This step is **required for the in-app changelog**: the notes only reach the app once a `main` deploy has rebuilt the asset. The app shows the version as the row title and the date on the right; a plain `## Unreleased` would display literally as "Unreleased", so make sure it was versioned in step 1.
4. **Push a `ios-v<version>` tag** — runs `.github/workflows/release-ios.yml` (macOS runner, final Xcode). The `e2e` job replays the four user journeys first (emulators + backend + simulator, see [docs/e2e.md](docs/e2e.md)) and **gates** the rest: archive → export → upload to App Store Connect via the App Store Connect API key (automatic signing). Build number = `git rev-list --count HEAD` (no manual `CURRENT_PROJECT_VERSION` bump), marketing version from the tag.

Because the gate fires on a tag that is already pushed, a red scenario means fixing and re-tagging. To check it beforehand, run `release-ios.yml` manually with **e2e_only** checked: it runs the scenario and stops there.

Because the CI runner is on a **final** macOS, the `BuildMachineOSBuild` patch below only concerns **local** archives made on the beta-macOS dev Mac.

**The dev Mac runs a beta macOS**, so archives made locally get a prerelease `BuildMachineOSBuild` stamp that App Store validation also rejects with ITMS-90111. After archiving, patch it to the latest **public** macOS build number *before* `-exportArchive` (export re-signs, so the patch survives):

```bash
# after `xcodebuild ... archive`, before `-exportArchive`:
plutil -replace BuildMachineOSBuild -string '<latest public macOS build>' \
  build/Vinarium.xcarchive/Products/Applications/Vinarium.app/Info.plist
```

Look up the current public macOS build at https://developer.apple.com/news/releases (pick the released macOS, not a beta/RC). Verify `DTXcodeBuild`/`DTSDKBuild` are untouched, then export. The clean alternative is to archive on a non-beta macOS (e.g. a GitHub Actions macOS runner with the final Xcode) — no patch needed. Bump `CURRENT_PROJECT_VERSION` (4 occurrences in `project.pbxproj`) for every new upload.

## API Token

The API token is used for authentication when `NITRO_API_TOKEN` is set. To rotate the token, update it in:
- `.env` (`NITRO_API_TOKEN=...`)
- `ios/Vinarium/Shared/Secrets.swift` (gitignored)
- `ios/VinariumUITests/Support/TestSecrets.swift` (gitignored)

See `.example` files next to the Secrets files for the expected format.

## Sentry Error Triage

When the user asks to look at a Sentry error (usually with an issue URL or ID), run this workflow:

1. **Token** — read `SENTRY_AUTH_TOKEN` from `.env` (gitignored; a Sentry user auth token, `sntryu_...`). Never echo, print, or commit it. Load it with `set -a; . ./.env; set +a` and reference `$SENTRY_AUTH_TOKEN` only inside the header.
2. **Read the issue** — the org is `polyforms`; take `{issue_id}` from the URL the user pastes (e.g. `https://polyforms.sentry.io/issues/<id>/`). Fetch context via the REST API with `-H "Authorization: Bearer $SENTRY_AUTH_TOKEN"`:
   - `GET https://sentry.io/api/0/organizations/{org}/issues/{issue_id}/`
   - `GET https://sentry.io/api/0/organizations/{org}/issues/{issue_id}/events/latest/`
3. **Diagnose** — use `superpowers:systematic-debugging`; trace the stack to the domain code.
4. **Fix** the bug.
5. **Regression test** — if it's a serious functional bug, write a test that fails before the fix and passes after (`*.unit/int/feat.test.ts` per the domain test conventions).
6. **Verify locally** — `bun tsc --noEmit` (+ `bunx nitro prepare` first if routes changed) and `bun test`.
7. **Commit** — push stays user-gated (never push until the user says "push").
8. **Resolve** — only **after** the user has pushed **and** CI is green (verify with `gh run list`/`watch` on `main`), mark the issue resolved:
   `PUT https://sentry.io/api/0/organizations/{org}/issues/{issue_id}/` with body `{"status":"resolved"}` and the same Bearer header.

## iOS Simulator

- Device: iPhone 17, OS 26.2

## iOS Physical Device Install

- After finishing a task (especially one touching iOS), **offer** to install it on the physical iPhone "TiPhone junior" (UDID `00008130-000A2068029A001C`, automatic dev signing, team `46C337T7YN`). Never install automatically — ask first, run only after a yes.
- On a yes, run `scripts/install-device.sh` to build → install → launch.
- The device must be connected, unlocked, and trusted. Relay the raw `xcodebuild`/`devicectl` output — don't claim success without it.


