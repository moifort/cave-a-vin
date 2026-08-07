# App Store submission — Vinarium (unlisted distribution)

Goal: publish Vinarium on the App Store as an **unlisted** app — reachable only via a
direct link, no expiry, no public discoverability. Steps marked **[ASC]** happen in
App Store Connect (need your login); the rest is prepared in this repo.

Facts: bundle `com.polyforms.vinarium.app`, team `46C337T7YN`, version `1.0` build `1`,
automatic signing, deployment target iOS 26.0, backend already deployed.

## Prepared in the repo (done)

- **Privacy policy** — `index.html` on the dedicated **`gh-pages`** branch (the `docs/`
  folder is gitignored on `main`), served at **https://moifort.github.io/vinarium/** (paste
  this as the Privacy Policy URL). To edit: `git checkout gh-pages`, change `index.html`,
  `git push`; GitHub Pages redeploys automatically.
- **Encryption declaration** — `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in the app
  target (uses only standard HTTPS), so App Store Connect won't ask about export compliance
  on every upload.
- **`ExportOptions.plist`** — App Store distribution options for the archive export.

## Phase 0 — Prerequisites [ASC]

- App Store Connect → **Business** (Agreements, Tax, Banking): the **Paid/Free Apps**
  agreement must be **active**, otherwise you cannot submit.

## Phase 1 — Create the app record [ASC]

- Apps → **＋ New App** → iOS, bundle `com.polyforms.vinarium.app`, name **Vinarium**,
  primary language **French**, SKU e.g. `vinarium-001`.

## Phase 2 — Metadata & privacy [ASC]

- **Description / keywords / support URL** (your GitHub repo URL is fine).
- **Privacy Policy URL**: `https://moifort.github.io/vinarium/`.
- **Terms of Use (EULA) link in every description** — guideline 3.1.2 refuses any submission
  selling auto-renewable subscriptions whose *metadata* carries no functional link to the terms,
  and the check is automated: 1.4 was refused on it on 2026-07-22, with the subscription group
  and both products left stuck behind the refused version. The listing files
  ([APP_STORE_LISTING.md](./APP_STORE_LISTING.md) for French,
  [APP_STORE_LISTING.localized.md](./APP_STORE_LISTING.localized.md) for the six other locales)
  end every description with Apple's standard EULA and the privacy policy, in the locale's own
  language. Paste them into each locale in App Store Connect: nothing pushes this listing
  automatically. The same two links are shown on the paywall (`SubscriptionLinks` in
  `PremiumSheet.swift`) — App Review wants them reachable from the purchase too, and both must
  actually answer.
- **Locales** — seven are declared since 1.4: `fr-FR` (primary), `en-US`, `de-DE`, `es-ES`,
  `it`, `pt-PT`, `ja`. Content lives in the two listing files above and matches what is
  published byte for byte; re-check with a SHA-256 of the description on both sides rather
  than by eye. Three rules learned the hard way on 2026-07-26:
  - **A locale can only be added while the version is *not* in review.** Editing existing
    metadata works in `WAITING_FOR_REVIEW`, creating a localization answers 409 `Cannot create
    localization after the app version has been submitted for review`. Adding one means pulling
    the version from review and resubmitting — plan locale work *before* submitting.
  - **Creating the `appInfoLocalization` auto-creates the matching
    `appStoreVersionLocalization`.** Create the first, then PATCH the second; a POST on it
    answers 409 `already exists`.
  - **Screenshots are shared across every language** (ASC says so on the version page), so a new
    locale needs no upload of its own.
- **App name in `en-US` is `Vinarium Wine Cellar`**, not `Vinarium`: Apple refuses the bare name
  there because another app holds it (409 `the app name is already being used`). The conflict is
  per storefront and **not** shared with `en-GB`, which took the plain `Vinarium` on 2026-07-29.
- **`en-GB`, `pt-BR` and `es-MX` were declared on 2026-07-29**, in the 1.5 cycle, from the
  content in [APP_STORE_LISTING.localized.md](./APP_STORE_LISTING.localized.md). Those three
  stores showed the *French* listing until then. Ten locales are now declared, and the
  release workflow writes a `release_notes.txt` for each of them: a locale `deliver` does not
  write keeps what it had, which on a new version is nothing. The translations have never had a
  native review pass — the note at the top of that file still stands.
- **App Privacy** questionnaire — answers to select:
  - Data collected & **linked to the user**:
    - *Contact info* → Name, Email (only if the user shares them via Sign in with Apple) — purpose **App Functionality**.
    - *User Content* → the wine catalog, tasting notes, photos of labels — purpose **App Functionality**.
    - *Identifiers* → the Apple user ID / account id — purpose **App Functionality**.
    - *Location* → Coarse/precise location, **only** the discovery place the user opts to save — purpose **App Functionality**.
  - **Not** used for tracking. **No** third-party advertising. **No** data used for tracking across apps.
- **Age rating**: no objectionable content → 4+ (answer "No" to everything; alcohol is *reference to*, set the alcohol/tobacco question to "Infrequent/Mild" if it appears → typically 17+ because the app is about alcohol; answer honestly).
- **Content rights**: you own or are licensed for all content → Yes.

## Phase 3 — Archive & upload [Xcode]

> **Automated release flow (recommended).** Two moving parts — the backend (which serves the
> in-app changelog) and the app binary. Do them in this order:
>
> 1. **Changelog** — write the user-facing notes (French) under `## Unreleased` in
>    `CHANGELOG.md`.
> 2. **Validation of the French notes** — show the French notes (`CHANGELOG.fr.md`) to the
>    maintainer and wait for an explicit approval before pushing. Corrections are applied and
>    mirrored across the other languages, then re-submitted. Nothing is pushed on unvalidated
>    notes.
> 3. **Push `main`** — `deploy.yml` deploys the backend *and* stamps `## Unreleased` →
>    `## YYYY.MM.DD`, regenerating `server/system/changelog-content.ts` (the changelog asset
>    served to the app over GraphQL). **This versioning is required**: the app parses `##`
>    headings — a dated `## YYYY.MM.DD` (dots) shows as a proper release, whereas
>    `## Unreleased` shows literally as "Unreleased". So the changelog only displays correctly
>    once it's been stamped by a `main` deploy.
> 4. **Push a `ios-v<version>` tag** (e.g. `ios-v1.1`) — runs
>    **`.github/workflows/release-ios.yml`** on a GitHub macOS runner: archive → export →
>    upload to App Store Connect (automatic signing driven by the App Store Connect API key).
>    Once the binary is up, the tag also pushes the marketing panels of
>    `screenshots/appstore/` (`.github/workflows/appstore-screenshots.yml`, called from the
>    release workflow) and only then submits the version for review — screenshots have to
>    land while the version is still editable.
>    The tag sets `MARKETING_VERSION` (`ios-v1.1` → `1.1`); the build number is
>    `git rev-list --count HEAD` — no manual `CURRENT_PROJECT_VERSION` bump. Also triggerable
>    from the Actions tab (`workflow_dispatch`). The runner is on a **final** macOS, so the
>    `BuildMachineOSBuild` patch below is unnecessary there.
> 5. **Attach the build** to the version in App Store Connect (Phase 4 below) once it finishes
>    processing.
>
> One-time setup — GitHub secrets: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (an App Store
> Connect API key with the *App Manager* role) and `IOS_GOOGLE_SERVICE_INFO_PLIST` (base64 of
> the gitignored `GoogleService-Info.plist`). Do **not** reuse the `APPLE_*` secrets — those
> are the *Sign in with Apple* AuthKey used by Terraform.

The manual archive/upload below stays as the fallback for step 4:

```bash
# 1. Archive (Release, real device destination)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ios/Vinarium.xcodeproj -scheme Vinarium \
  -destination 'generic/platform=iOS' \
  -archivePath build/Vinarium.xcarchive archive

# 2. Export a signed .ipa using ExportOptions.plist
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -exportArchive \
  -archivePath build/Vinarium.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/export
```

Then upload `build/export/Vinarium.ipa` with the **Transporter** app (drag & drop) or via
**Xcode → Organizer → Distribute App**. The build appears in App Store Connect after a few
minutes; attach it to the 1.0 version.

(Easiest alternative: skip the CLI and do Xcode → Product → Archive → Organizer → Distribute App.)

## Phase 4 — Submit for review [ASC]

- **App Review Information → Notes**: "The app requires Sign in with Apple; reviewers can
  sign in with their own Apple ID and an account is created automatically. No demo account
  needed. The backend runs in production." (No demo login required.)
- Screenshots: at least the 6.9"/6.7" iPhone size. Capture from the iPhone 17 simulator once
  signed in (Cmd+S in the simulator saves a correctly-sized PNG).
- Marketing screenshots (panoramas in `screenshots/appstore/`, five 1320x2868 PNGs): regenerate
  with `bun scripts/generate-appstore-previews.ts [1|2]` (Nano Banana Pro renders the panorama,
  real screenshots from `screenshots/` are composited onto the phone screens, then the panorama
  is sliced into panels). The upload is carried by the release tag; to push panels between
  two releases, run the **App Store screenshots** workflow from the Actions tab (it replaces
  every screenshot of the editable version, so the version must not be in review).
- **Submit for Review**. Optionally set manual release to keep control.

## Phase 5 — Make it unlisted [ASC + form]

- Once the app is **approved** (you can hold the public release), request unlisted
  distribution: **https://developer.apple.com/contact/request/unlisted-app-distribution**
  (some accounts also expose an unlisted option in App Store Connect at publish time).
- Apple grants a direct `apps.apple.com/...` link that is hidden from search, charts and
  browsing. Share it with whoever should get the app — no device limit, no expiry, automatic
  updates.

## Updates later

Bump `CURRENT_PROJECT_VERSION` (build number), re-archive (Phase 3), submit (Phase 4).
Installed users update automatically like any App Store app.
