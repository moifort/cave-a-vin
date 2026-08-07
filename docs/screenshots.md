# Screenshots

Two audiences read the same captures: the README, and the App Store. Both come
from one pipeline, so a screen that changes is re-photographed once.

```
scripts/screenshots.sh          the app, running for real, photographed
        │                       (emulators + Nitro + simulator)
        ▼
screenshots/*.png               French, what the README embeds
screenshots/<lang>/*.png        the six other App Store languages
        │
        ▼
scripts/generate-appstore-previews.ts
        │                       scene + captions + slicing
        ▼
screenshots/appstore/<lang>/*.png   the five panels uploaded to App Store Connect
```

## Capturing

```bash
scripts/screenshots.sh            # French, into screenshots/
scripts/screenshots.sh all        # the seven languages
scripts/screenshots.sh de ja      # a subset
```

The script runs the same local stack as the end-to-end gate — Firebase
emulators, the Nitro server, the iPhone simulator — so nothing reaches
production and no AI quota is spent (the scan is stubbed). It captures on an
**iPhone 17 Pro Max**, whose screen is the 6.9" size the store asks for; the
gate keeps its own pinned simulator, since it tests behaviour rather than
pixels. It needs a JDK, like
[the e2e run](./e2e.md).

Two pieces make it work:

- **`scripts/seed-screenshot-cellar.ts`** fills one fixed account
  (`screenshots@vinarium.test`) through the public GraphQL API: twenty-odd
  bottles spread over regions and colours, some placed in the grid, a few
  favourites, tasting notes, and three bottles drunk so the journal has a
  history. An empty cellar photographs badly, and a screenshot of a wizard sells
  nothing.
- **`ios/VinariumUITests/Tests/ScreenshotTest.swift`** signs into that account
  and walks the seven screens. It deliberately avoids the page objects the
  scenarios use: those assert on English copy, and this runs in each shipped
  language. Navigation goes by accessibility identifier, falling back to tab
  position, both of which say the same thing in every language.

The language travels from the script to the test through
`build/screenshot-language`, a one-line file, rather than an environment
variable: `TEST_RUNNER_<NAME>=value` on the xcodebuild command line does not
reach the test process here. The failure it caused is worth remembering — the
run captured the default language while reporting the one it was asked for, and
overwrote the captures it should have sat beside. The script now also refuses a
run that produced fewer than seven files, so a green test that wrote nothing
cannot pass for a success.

If a capture comes out on a loading state, the fix is to wait on an
identifier that only exists once the screen has its data — not to add a sleep.

One known limitation: every journal entry carries the day the seed ran, because
the journal timestamps the movement and the public API has no way to backdate
one. The screen is real, its history is just one day deep. Spreading it would
mean seeding through the portability envelope instead of the mutations, which
trades a readable seed for a hand-built internal payload — not worth it for one
date header.

## The App Store panels

```bash
bun scripts/generate-appstore-previews.ts             # every language
bun scripts/generate-appstore-previews.ts --lang fr 1 # one language, one panorama
bun scripts/generate-appstore-previews.ts --regenerate # draw new scenes
```

Each panorama is one image sliced into 1320x2868 panels — the 6.9" App Store
size, which is the iPhone 17 Pro Max's own screen, so a capture is never
rescaled — and the background flows from one App Store screenshot to the next.
The first panorama carries three panels (dashboard, cellar, wine list), the
second two (scan, wine detail). A scene is always drawn three panels wide,
whatever uses it: a shorter panorama keeps its left panels, which is why one
prompt and one cache serve both.

Three things are kept away from the image model on purpose:

- **The app's UI.** The model renders plausible-looking but wrong text
  ("Appelletion", "Eortie"), so `scripts/composite-panorama.swift` pastes the
  real captures instead.
- **The captions.** Same reason, times seven languages. The compositor sets them
  with Core Text, in the system font for the language, shrinking and wrapping to
  fit — which is how a German compound word and a Japanese line can share one
  layout.
- **The device.** Asked for a phone at a given size, the model returned a
  different size on every run and a different one per panel — the one thing that
  cannot vary, since the panels are read side by side. The compositor draws it:
  the same rect on every panel, titanium rail, side buttons, the screenshot
  clipped to the screen's corners.

The generated scenes are cached in `screenshots/appstore/scenes/` and committed:
adding a language or rewording a caption then costs nothing and needs no API
key. `--regenerate` is the only path that calls the model, and it needs
`NITRO_GOOGLE_API_KEY`.

## Uploading

A release tag does it: `release-ios.yml` calls `appstore-screenshots.yml` once the
binary is uploaded and before the version is submitted, so the panels shipped with
the app are the ones that reach the store. The order matters — a version already in
review refuses new screenshots.

Between two releases, run the **App Store screenshots** workflow from the Actions
tab, or locally:

```bash
cd infra && bundle exec fastlane screenshots
```

Uploads the panels and nothing else, staging the language directories into the
App Store's locale names, and replacing whatever the version carried. Needs
`ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH` — the same App Store Connect key
the release uses, which lives in the GitHub secrets and not on the dev Mac.

## The listing text

`infra/fastlane/metadata/<locale>/` holds what the product page says, one
directory per App Store locale: `description.txt`, `keywords.txt` and
`promotional_text.txt`. It is versioned so a wording change is read as a diff
rather than typed into seven web forms, and `deliver` pushes it with the
release (the `submit` lane, which is why nothing here is behind `skip_metadata`).
`release_notes.txt` is the exception: release-ios.yml writes it from the
changelogs at release time, so it stays ignored.

A published version's page is frozen in App Store Connect — description,
keywords and screenshots only become editable again on the next version. The
promotional text is the one field Apple lets through at any time.
