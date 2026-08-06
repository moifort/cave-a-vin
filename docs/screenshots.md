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
screenshots/appstore/<lang>/*.png   the six panels uploaded to App Store Connect
```

## Capturing

```bash
scripts/screenshots.sh            # French, into screenshots/
scripts/screenshots.sh all        # the seven languages
scripts/screenshots.sh de ja      # a subset
```

The script runs the same local stack as the end-to-end gate — Firebase
emulators, the Nitro server, the iPhone simulator — so nothing reaches
production and no AI quota is spent (the scan is stubbed). It needs a JDK, like
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
bun scripts/generate-appstore-previews.ts --lang fr 1 # one language, one triptych
bun scripts/generate-appstore-previews.ts --regenerate # draw new scenes
```

Each triptych is one panoramic image sliced into three 1206x2622 panels, so the
background flows from one App Store screenshot to the next.

Two things are kept away from the image model on purpose:

- **The app's UI.** The model renders plausible-looking but wrong text
  ("Appelletion", "Eortie"). So it draws phones with flat magenta screens and
  `scripts/composite-panorama.swift` pastes the real captures onto them.
- **The captions.** Same reason, times seven languages. The compositor sets them
  with Core Text, in the system font for the language, shrinking and wrapping to
  fit — which is how a German compound word and a Japanese line can share one
  layout.

The generated scenes are cached in `screenshots/appstore/scenes/` and committed:
adding a language or rewording a caption then costs nothing and needs no API
key. `--regenerate` is the only path that calls the model, and it needs
`NITRO_GOOGLE_API_KEY`.

## The bento panel

The five other panels each show one screen. The last one shows the range, which
is what someone swiping to the end is asking about:

```bash
bun scripts/generate-bento-panel.ts            # every language
bun scripts/generate-bento-panel.ts --lang ja  # one language
```

`scripts/bento-panel.html` is a page pinned to 1206x2622 that Chrome renders
headless, so nothing is scaled or cropped afterwards. It is drawn rather than
photographed because no single screen in the app shows all of this, and a
mosaic of real tiles beats a montage of cropped screenshots. Its palette and
tile language come from the landing page (`portfolio`, `[data-theme='vinarium']`)
so the store and the site read as one product; the artwork it needs lives in
`screenshots/appstore/bento-assets/`.

## Uploading

```bash
cd infra && bundle exec fastlane screenshots
```

Uploads the panels and nothing else, staging the language directories into the
App Store's locale names. Needs `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH`
— the same App Store Connect key the release uses.
