# End-to-End Tests

## Overview

One scenario, replayed against the whole product before every App Store release: the real app on a simulator, the real Nitro backend, and Firebase emulators standing in for Firestore and Auth.

```
Firebase emulators (auth :9099, firestore :8080)   ← the only storage and identity
  └─ Nitro dev server :3000 (NITRO_SCAN_STUB=1)    ← the real backend
       └─ iPhone simulator                          ← the real app, driven by XCUITest
```

Nothing reaches production. The emulators start empty and are discarded when the run ends, so there is no reset endpoint, no test account to maintain in the cloud project, and no AI quota spent.

```bash
./scripts/e2e.sh
```

Requires `bun`, Xcode, and a JDK for the Firestore emulator (`brew install openjdk` — the script finds Homebrew's keg-only install on its own, no profile to edit).

A run takes about 9 minutes, 6 of them in the four scenarios. They share one emulator run — each test signs in with an account of its own, so none sees another's cellar.

## What the scenarios cover

### Cellar — `CellarFlowTest`

The main journey, a new account taken through the product end to end:

1. **Onboarding** — prénom, cellar dimensions, finish (`completeOnboarding` provisions the grid)
2. **Scan** — the bundled label photo, the review form, add to cellar (`scanBeverage`, quota, `addBeverage`)
3. **Placement** — slot A1, confirmation (`placeBottle`)
4. **Cellar** — the bottle is there, its detail shows the cellar section
5. **Journal** — an "Entrée" entry exists and opens
6. **Wine list** — the bottle is listed and opens
7. **Dashboard** — the bottle count reads 1, the journal shows the entry
8. **Consumption** — remove from the cellar with 5 stars and a note (`consumeBottle`)
9. **Favorites** — flag it from the detail menu, then find it under the favorites filter (`recordTasting`)
10. **Deletion** — deleting it removes it from the list (`deleteBeverage` cascades)

### Favorite — `FavoriteFlowTest`

Scan, flag the bottle favorite from the form's inline toggle, save without placing it, then find it under the favorites filter and in the dashboard's favorites section.

### Gift — `GiveAsGiftFlowTest`

Scan, place, then give the bottle away with a recipient name. It leaves the cellar, stays in the full list, and its detail shows the "Offert" section. Note that the **Offerts** filter is not involved: it holds bottles *received* as a gift (`gift.received`), not given ones.

### Recommendation — `RecommendationFlowTest`

Scan, fill "Conseillé par", save, then find the bottle under the recommended filter with its recommendation section.

Together they cover nine domains: user, beverage, cellar, journal, dashboard, tasting, quota, gift, recommendation.

Out of scope, and still manual before a release: Sign in with Apple, in-app purchases, and the real Gemini scan.

Run a single scenario with:

```bash
E2E_TESTS=VinariumUITests/GiveAsGiftFlowTest ./scripts/e2e.sh
```

## How the pieces fit

### Signing in without Apple

`SignInWithAppleButton` opens a system sheet XCUITest cannot drive, so an end-to-end run never uses it. [`UITestEnvironment`](../ios/Vinarium/Shared/UITestEnvironment.swift) — compiled only in Debug, so absent from the App Store archive — reads two launch arguments, points Firebase Auth at the emulator and creates the account:

```
-uiTestAuthEmulator 127.0.0.1:9099
-uiTestAccount      e2e-<uuid>@vinarium.test
```

Each test gets its own random address, so two tests in one run never share a cellar. The server URL rides `-serverURL`, which `APIClient` already reads through `UserDefaults`.

The emulators run under the project id read from `GoogleService-Info.plist` (`vinarium-prod`). That is deliberate and harmless: a Firebase ID token carries its project as audience, so `verifyIdToken` would reject a token minted under any other name. The emulators are local processes; only the name is shared.

### Not calling Gemini

`NITRO_SCAN_STUB=1` makes `Scan.scanWithCache` answer with a fixed label instead of calling the models. The models cost money, take seconds and never answer twice the same — none of which a release gate can rely on. The real scan path stays covered by `server/domain/scan/scan.int.test.ts`.

### Not writing to production

`scripts/e2e.sh` exports `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`, and refuses to start the server if either is missing. Without them, `initializeApp()` connects to the real project and the run would write test bottles into production.

## The release gate

The `e2e` job in [`release-ios.yml`](../.github/workflows/release-ios.yml) runs the scenario on `macos-26`; the build-and-upload job declares `needs: e2e`, so a red scenario stops the release.

The gate fires on a tag that is already pushed, so a failure means fixing and re-tagging. To avoid that, run the workflow manually with **e2e_only** checked before tagging: it runs the gate and stops there.

## Debugging a failure

- CI uploads `build/e2e.xcresult` as an artifact on failure — open it in Xcode to see the screenshot at the point of failure.
- The script prints the last 50 lines of the server log when the tests fail; the full log path is printed at startup.
- To watch a run locally, open the emulator UI at http://localhost:4000 while it runs.
- A failure on the very first step ("Onboarding never appeared") is almost always sign-in: check the server log for a 401, and that the emulators came up under the right project. A keychain error (`-34018`) there means the app was built without signing — a simulator build must keep its ad-hoc signature, or Firebase Auth cannot write its session.
- "Multiple matching elements found" is usually a `confirmationDialog`, which lists each button twice in the accessibility tree — query it through `firstMatch`. Conversely, items of a `Menu` carry no accessibility identifier at all and have to be matched by label.
- Screen titles follow the segmented control (`Ma Cave` / `Journal`, `Mes Vins` / `Favoris`), so a page object waiting on a title must first put the segment back where it expects it.
- Typing into a pre-filled field is the other classic: tapping it drops the caret mid-word, so deletes only eat what is left of it and the new value lands inside the old one. Tap past the last character, then assert what the field ends up holding — the failure otherwise surfaces three steps later as "bottle not found".
- A field further down a `Form` does not exist in the accessibility tree until it is scrolled into view; `app.scrollTo(_:)` handles it.
