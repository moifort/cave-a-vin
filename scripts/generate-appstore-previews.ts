#!/usr/bin/env bun
/**
 * Generates App Store marketing screenshots ("triptychs") with Nano Banana Pro.
 *
 * Each triptych is ONE continuous 4:3 panorama: Nano Banana Pro renders an
 * empty room, then composite-panorama.swift draws the three devices, pastes the
 * real app screenshots into them and sets the caption above each. The panorama
 * is finally sliced into three 1206x2622 portrait panels (the 6.9" size App
 * Store Connect accepts) so the background flows across adjacent App Store
 * screenshots.
 *
 * The model is given the room and nothing else. It garbles any text it draws,
 * so the captions are set in Core Text; and asked for a phone at a given size it
 * returned a different one on every run and a different one per panel, so the
 * devices are placed by hand. What is left — light, wood, depth — is what it is
 * good at. One scene per triptych, cached, reused by every language.
 *
 * Usage:
 *   bun scripts/generate-appstore-previews.ts                  # every language, both triptychs
 *   bun scripts/generate-appstore-previews.ts --lang fr        # one language
 *   bun scripts/generate-appstore-previews.ts --lang fr,en 1   # one triptych
 *   bun scripts/generate-appstore-previews.ts --regenerate     # new scenes (costs API calls)
 *
 * Reads the captures from screenshots/<lang>/ (screenshots/ for French, which is
 * what the README uses) and writes screenshots/appstore/<lang>/.
 * Requires NITRO_GOOGLE_API_KEY in .env (loaded automatically by bun).
 */
import { mkdir, mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { $ } from 'bun'

const MODEL = 'gemini-3-pro-image'
const PANEL_WIDTH = 1206
const PANEL_HEIGHT = 2622
const TRIPTYCH_WIDTH = PANEL_WIDTH * 3

const repoRoot = join(import.meta.dir, '..')
const screenshotsDir = join(repoRoot, 'screenshots')
const appstoreDir = join(screenshotsDir, 'appstore')
// Committed, not temporary: a scene costs an API call, and changing a caption
// or adding a language must not need an API key — only the compositor.
const sceneCacheDir = join(appstoreDir, 'scenes')
const compositor = join(import.meta.dir, 'composite-panorama.swift')

const LANGUAGES = ['fr', 'en', 'de', 'es', 'it', 'pt', 'ja'] as const
type Language = (typeof LANGUAGES)[number]

type Panel = { source: string; output: string; captions: Record<Language, string> }
type Triptych = {
  id: number
  scene: string
  /** One sentence saying what the app does, set under every title of the
   *  triptych. The titles say what each panel shows; this says what it is for. */
  subtitles?: Record<Language, string>
  panels: [Panel, Panel, Panel]
}

// What the app does, in one line. Repeated across a triptych on purpose: an App
// Store visitor swipes through the panels one at a time and may well start on
// the second, so the sentence has to be under whichever one they land on.
const WHAT_THE_APP_DOES: Record<Language, string> = {
  fr: "Ce que vous avez, où c'est rangé, quand le boire.",
  en: 'What you own, where it sits, when to drink it.',
  de: 'Was du hast, wo es liegt, wann du es trinkst.',
  es: 'Lo que tienes, dónde está, cuándo beberlo.',
  it: "Cosa hai, dov'è, quando berlo.",
  pt: 'O que tem, onde está, quando beber.',
  ja: '何があるか、どこにあるか、いつ飲むか。',
}

const TRIPTYCHS: Triptych[] = [
  {
    id: 1,
    scene:
      'a moody high-end wine cellar: dark oak shelves filled with wine bottles, warm amber glow ' +
      'from recessed lights, deep burgundy-to-plum tones',
    subtitles: WHAT_THE_APP_DOES,
    panels: [
      {
        source: 'dashboard.png',
        output: '01-accueil.png',
        captions: {
          fr: "Votre cave en un coup d'œil",
          en: 'Your cellar at a glance',
          de: 'Dein Weinkeller auf einen Blick',
          es: 'Tu bodega de un vistazo',
          it: "La tua cantina in un colpo d'occhio",
          pt: 'A sua adega num relance',
          ja: 'セラーをひと目で',
        },
      },
      {
        source: 'cellar.png',
        output: '02-cave.png',
        captions: {
          fr: 'Une place précise pour vos bouteilles',
          en: 'A precise spot for every bottle',
          de: 'Ein fester Platz für jede Flasche',
          es: 'Un sitio exacto para cada botella',
          it: 'Un posto preciso per ogni bottiglia',
          pt: 'Um lugar exato para cada garrafa',
          ja: '一本ずつ、決まった場所に',
        },
      },
      {
        source: 'wine-list.png',
        output: '03-vins.png',
        captions: {
          fr: 'Retrouver une bouteille parmi des milliers',
          en: 'Find one bottle among thousands',
          de: 'Eine Flasche unter Tausenden finden',
          es: 'Encuentra una botella entre miles',
          it: 'Trova una bottiglia tra migliaia',
          pt: 'Encontre uma garrafa entre milhares',
          ja: '何千本の中から、一本を',
        },
      },
    ],
  },
  {
    id: 2,
    scene:
      'an elegant tasting-room scene: dark wood surface, a glass of red wine and a fine bottle in ' +
      'soft bokeh, warm candle-like ambient light, subtle burgundy-to-plum gradient',
    panels: [
      {
        // The review form, not the viewfinder: a simulator has no camera, so
        // the scan screen photographs as a white rectangle. The form the AI
        // filled shows what the feature is worth — the answer rather than the
        // tool.
        source: 'scan-review.png',
        output: '04-scan.png',
        captions: {
          fr: "Scannez, l'IA fait le reste",
          en: 'Scan it, the AI does the rest',
          de: 'Scannen, die KI macht den Rest',
          es: 'Escanea, la IA hace el resto',
          it: "Scansiona, ci pensa l'IA",
          pt: 'Digitalize, a IA faz o resto',
          ja: '撮るだけ、あとはAIが',
        },
      },
      {
        source: 'wine-detail.png',
        output: '05-fiche-vin.png',
        // Says what the capture shows, not what the screen can show: the drink
        // window sits below the fold, and a caption promising it would be read
        // against a panel that does not have it.
        captions: {
          fr: 'Origine, millésime, emplacement',
          en: 'Origin, vintage, position',
          de: 'Herkunft, Jahrgang, Platz',
          es: 'Origen, añada, ubicación',
          it: 'Origine, annata, posizione',
          pt: 'Origem, colheita, localização',
          ja: '産地、ヴィンテージ、位置',
        },
      },
      {
        source: 'journal.png',
        output: '06-journal.png',
        captions: {
          fr: 'Revivez chaque dégustation',
          en: 'Relive every tasting',
          de: 'Jede Verkostung noch einmal erleben',
          es: 'Revive cada cata',
          it: 'Rivivi ogni degustazione',
          pt: 'Reviva cada prova',
          ja: '味わいの記録を、もう一度',
        },
      },
    ],
  },
]

const buildPrompt = (triptych: Triptych) =>
  `You are designing App Store marketing screenshots for "Vinarium", a premium French wine-cellar management iOS app.

Create ONE single seamless panoramic marketing image (4:3 landscape). It will be sliced vertically into THREE equal portrait panels (left, center, right) shown side by side on the App Store, so:

- The background is one continuous scene flowing across the whole image with no visible seams: ${triptych.scene}.
- The scene FILLS THE ENTIRE FRAME, edge to edge and corner to corner, like a single photograph taken in one place. No borders, no letterboxing, no horizontal bands, no flat colour blocks, no blurred strip along the top or the bottom, no vignette, no visible boundary between an upper and a lower area — any straight horizontal edge across the image is a defect, and so is a band of blur that does not belong to the depth of the scene.
- Sharpness is even across the whole height: the top of the image is as much part of the room as the middle, only further away. Do not darken, fade or defocus any area to leave room for text.
- NO phone, no device, no screen, no tablet, no object shaped like one anywhere in the image. The devices are drawn afterwards by the compositor, at an exact size and position: asked for them, the model returned a different size on every run and a different one per panel, and the three panels are read side by side.
- The middle of each third is where a device will stand, covering roughly 80% of the height: keep those three areas free of anything the eye would miss — no bottle, no candle, no lamp centered in a third. Interest belongs at the sides.
- ABSOLUTELY NO TEXT anywhere in the image: no captions, no labels, no logos, no watermarks, no lettering of any kind. Every word is added later.
- CRITICAL composition rule: the image will be cut along two vertical lines at exactly 1/3 and 2/3 of the width. Nothing that reads as a single object may straddle those lines: the scene crosses them, a bottle standing on one does not.
- Palette: deep burgundy (#8C1229), plum, warm gold accents (#D4AE59); dark, sophisticated, high-end wine brand aesthetic.`

// Only needed to draw a new scene. Rendering a language onto a cached one asks
// nothing of the network, which is the common case.
const apiKey = process.env.NITRO_GOOGLE_API_KEY

/** Where a language's captures live. French sits at the root: the README reads it. */
const sourceDir = (language: Language) =>
  language === 'fr' ? screenshotsDir : join(screenshotsDir, language)

const generateScene = async (triptych: Triptych, target: string) => {
  if (!apiKey) throw new Error('NITRO_GOOGLE_API_KEY is not set (expected in .env)')
  console.log(`Triptych ${triptych.id}: generating the scene with ${MODEL}...`)
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
    {
      method: 'POST',
      headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: buildPrompt(triptych) }] }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
          imageConfig: { aspectRatio: '4:3', imageSize: '4K' },
        },
      }),
    },
  )
  if (!response.ok) throw new Error(`Gemini API error ${response.status}: ${await response.text()}`)
  const result = (await response.json()) as {
    candidates?: { content?: { parts?: { inlineData?: { data: string } }[] } }[]
  }
  const image = result.candidates?.[0]?.content?.parts?.find((part) => part.inlineData)?.inlineData
  if (!image) throw new Error(`No image in response: ${JSON.stringify(result).slice(0, 2000)}`)
  await Bun.write(target, Buffer.from(image.data, 'base64'))
}

// Normalize the scene to exactly 3618x2622 so screenshots are composited at
// final resolution (a single downscale) before the panorama is cut into columns.
const normalize = async (path: string) => {
  await $`sips --resampleWidth ${TRIPTYCH_WIDTH} ${path}`.quiet()
  // If the model ignored the 4:3 ratio and the resampled height falls short, the crop below
  // would silently PAD the image with background instead of cropping — reject that upfront.
  const size = await $`sips -g pixelHeight ${path}`.text()
  const height = Number(size.match(/pixelHeight: (\d+)/)?.[1])
  if (!(height >= PANEL_HEIGHT))
    throw new Error(
      `Scene is only ${TRIPTYCH_WIDTH}x${height} after resampling, needs ${PANEL_HEIGHT} of height`,
    )
  await $`sips -c ${PANEL_HEIGHT} ${TRIPTYCH_WIDTH} ${path}`.quiet()
}

/** The generated scene, from the cache when it is there. */
const sceneFor = async (triptych: Triptych, regenerate: boolean) => {
  const cached = join(sceneCacheDir, `scene-${triptych.id}.png`)
  if (!regenerate && (await Bun.file(cached).exists())) {
    console.log(`Triptych ${triptych.id}: reusing the cached scene`)
    return cached
  }
  await generateScene(triptych, cached)
  await normalize(cached)
  return cached
}

const renderLanguage = async (
  triptych: Triptych,
  scene: string,
  language: Language,
  workDir: string,
) => {
  const sources = triptych.panels.map((panel) => join(sourceDir(language), panel.source))
  for (const source of sources)
    if (!(await Bun.file(source).exists()))
      throw new Error(`Missing capture: ${source} — run scripts/screenshots.sh ${language}`)

  const panorama = join(workDir, `panorama-${triptych.id}-${language}.png`)
  await $`cp ${scene} ${panorama}`.quiet()
  const captions = triptych.panels.map((panel) => panel.captions[language])
  const subtitle = triptych.subtitles?.[language] ?? ''
  await $`swift ${compositor} ${panorama} ${sources[0]} ${sources[1]} ${sources[2]} ${language} ${captions[0]} ${captions[1]} ${captions[2]} ${subtitle}`.quiet()

  const outputDir = join(appstoreDir, language)
  await mkdir(outputDir, { recursive: true })
  for (const [index, panel] of triptych.panels.entries()) {
    const panelPath = join(outputDir, panel.output)
    await $`cp ${panorama} ${panelPath}`.quiet()
    // offsetY is 1 (not 0) because sips ignores an all-zero --cropOffset and falls back to a
    // centered crop; 1 gets clamped back to the top edge since the crop is full-height.
    await $`sips -c ${PANEL_HEIGHT} ${PANEL_WIDTH} --cropOffset 1 ${index * PANEL_WIDTH} ${panelPath}`.quiet()
    console.log(`  ${panelPath}`)
  }
}

const argv = process.argv.slice(2)
const regenerate = argv.includes('--regenerate')
const languageArgument = argv[argv.indexOf('--lang') + 1]
const languages = argv.includes('--lang')
  ? (languageArgument?.split(',') as Language[])
  : [...LANGUAGES]
for (const language of languages)
  if (!LANGUAGES.includes(language)) {
    console.error(`Unknown language "${language}" (expected one of ${LANGUAGES.join(', ')})`)
    process.exit(1)
  }
const requested = argv.find((argument) => /^[12]$/.test(argument))
const triptychs = requested ? TRIPTYCHS.filter((t) => t.id === Number(requested)) : TRIPTYCHS

await mkdir(sceneCacheDir, { recursive: true })
const workDir = await mkdtemp(join(tmpdir(), 'vinarium-previews-'))
for (const triptych of triptychs) {
  const scene = await sceneFor(triptych, regenerate)
  for (const language of languages) {
    console.log(`Triptych ${triptych.id}, ${language}:`)
    await renderLanguage(triptych, scene, language, workDir)
  }
}
console.log('Done.')
