#!/usr/bin/env bun
/**
 * Renders the "everything the app does" App Store panel — a bento mosaic in the
 * landing page's visual language — into screenshots/appstore/<lang>/06-bento.png.
 *
 * The five other panels each show one screen; this one shows the range, which is
 * what a visitor swiping to the end is asking about. It is drawn from HTML
 * rather than photographed: there is no single screen in the app that shows all
 * of this, and a mosaic of real tiles beats a montage of cropped screenshots.
 *
 * Chrome renders it headless at exactly 1320x2868 — the 6.9" App Store size,
 * which is the iPhone 17 Pro Max's own screen — so nothing is scaled or cropped
 * afterwards.
 *
 * Usage:
 *   bun scripts/generate-bento-panel.ts             # every language
 *   bun scripts/generate-bento-panel.ts --lang fr   # one language
 */
import { mkdir, rm, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { $ } from 'bun'

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const WIDTH = 1320
const HEIGHT = 2868

const repoRoot = join(import.meta.dir, '..')
const template = join(import.meta.dir, 'bento-panel.html')
const appstoreDir = join(repoRoot, 'screenshots', 'appstore')

const LANGUAGES = ['fr', 'en', 'de', 'es', 'it', 'pt', 'ja'] as const
type Language = (typeof LANGUAGES)[number]

/** Every string the panel shows, per language. */
const COPY: Record<Language, Record<string, string>> = {
  fr: {
    TITLE: 'Tout ce que votre cave sait faire',
    SUBTITLE: "Ce que vous avez, où c'est rangé, quand le boire.",
    LOCATION: 'Lieu de découverte',
    FAVORITES: 'Favoris',
    SPIRITS: 'Grands spiritueux',
    AI: 'Analyse IA',
    NOTES: 'Commentaires',
    READY: 'Prêt à boire',
    BEFORE: 'Avant',
    SAKE: 'Saké et plus',
    RATING: 'Notes de dégustation',
    SHARING: 'Partage du foyer',
    PRICE: 'Estimation du prix',
  },
  en: {
    TITLE: 'Everything your cellar can do',
    SUBTITLE: 'What you own, where it sits, when to drink it.',
    LOCATION: 'Where you found it',
    FAVORITES: 'Favourites',
    SPIRITS: 'Fine spirits',
    AI: 'AI analysis',
    NOTES: 'Tasting notes',
    READY: 'Ready to drink',
    BEFORE: 'Before',
    SAKE: 'Sake and more',
    RATING: 'Ratings',
    SHARING: 'Shared household',
    PRICE: 'Price estimate',
  },
  de: {
    TITLE: 'Alles, was dein Weinkeller kann',
    SUBTITLE: 'Was du hast, wo es liegt, wann du es trinkst.',
    LOCATION: 'Fundort',
    FAVORITES: 'Favoriten',
    SPIRITS: 'Edle Spirituosen',
    AI: 'KI-Analyse',
    NOTES: 'Notizen',
    READY: 'Trinkreif',
    BEFORE: 'Vor',
    SAKE: 'Sake und mehr',
    RATING: 'Bewertungen',
    SHARING: 'Gemeinsamer Keller',
    PRICE: 'Preisschätzung',
  },
  es: {
    TITLE: 'Todo lo que tu bodega puede hacer',
    SUBTITLE: 'Lo que tienes, dónde está, cuándo beberlo.',
    LOCATION: 'Dónde la encontraste',
    FAVORITES: 'Favoritos',
    SPIRITS: 'Grandes destilados',
    AI: 'Análisis con IA',
    NOTES: 'Comentarios',
    READY: 'Listo para beber',
    BEFORE: 'Antes de',
    SAKE: 'Sake y más',
    RATING: 'Notas de cata',
    SHARING: 'Bodega compartida',
    PRICE: 'Precio estimado',
  },
  it: {
    TITLE: 'Tutto quello che la cantina sa fare',
    SUBTITLE: "Cosa hai, dov'è, quando berlo.",
    LOCATION: 'Dove l’hai trovata',
    FAVORITES: 'Preferiti',
    SPIRITS: 'Grandi distillati',
    AI: 'Analisi con IA',
    NOTES: 'Commenti',
    READY: 'Pronto da bere',
    BEFORE: 'Entro il',
    SAKE: 'Sake e altro',
    RATING: 'Valutazioni',
    SHARING: 'Cantina condivisa',
    PRICE: 'Prezzo stimato',
  },
  pt: {
    TITLE: 'Tudo o que a sua adega sabe fazer',
    SUBTITLE: 'O que tem, onde está, quando beber.',
    LOCATION: 'Onde a encontrou',
    FAVORITES: 'Favoritos',
    SPIRITS: 'Grandes destilados',
    AI: 'Análise com IA',
    NOTES: 'Comentários',
    READY: 'Pronto a beber',
    BEFORE: 'Antes de',
    SAKE: 'Saqué e mais',
    RATING: 'Notas de prova',
    SHARING: 'Adega partilhada',
    PRICE: 'Preço estimado',
  },
  ja: {
    TITLE: 'セラーにできること、すべて',
    SUBTITLE: '何があるか、どこにあるか、いつ飲むか。',
    LOCATION: '出会った場所',
    FAVORITES: 'お気に入り',
    SPIRITS: '蒸留酒も',
    AI: 'AI解析',
    NOTES: 'コメント',
    READY: '飲み頃',
    BEFORE: '',
    SAKE: '日本酒も',
    RATING: 'テイスティング評価',
    SHARING: '家族と共有',
    PRICE: '価格の目安',
  },
}

const render = async (language: Language) => {
  const copy = COPY[language]
  const html = (await Bun.file(template).text()).replace(/\{\{(\w+)\}\}/g, (whole, key: string) =>
    key === 'LANG' ? language : (copy[key] ?? whole),
  )

  // Written beside the assets so the relative image paths resolve, and removed
  // afterwards: it is a render input, not an artefact worth keeping. The name
  // carries a timestamp because Chrome caches by URL — reusing one path served
  // the previous render and a CSS fix looked like it had changed nothing.
  const page = join(appstoreDir, `bento-${language}-${Date.now()}.html`)
  await writeFile(page, html)

  const outputDir = join(appstoreDir, language)
  await mkdir(outputDir, { recursive: true })
  // Last of the panels, and named for the rank the store reads them in: the
  // directory is uploaded as it sorts.
  const output = join(outputDir, '06-bento.png')

  // `--window-size` is the CSS viewport and the body is pinned to it, so the
  // screenshot comes out at the exact App Store size with nothing to crop.
  await $`${CHROME} --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=${WIDTH},${HEIGHT} --screenshot=${output} --virtual-time-budget=4000 ${`file://${page}`}`.quiet()
  await rm(page)
  console.log(`  ${output}`)
}

const argv = process.argv.slice(2)
const requested = argv.includes('--lang') ? argv[argv.indexOf('--lang') + 1]?.split(',') : undefined
const languages = (requested ?? [...LANGUAGES]) as Language[]
for (const language of languages)
  if (!LANGUAGES.includes(language)) {
    console.error(`Unknown language "${language}" (expected one of ${LANGUAGES.join(', ')})`)
    process.exit(1)
  }

for (const language of languages) {
  console.log(`Bento, ${language}:`)
  await render(language)
}
console.log('Done.')
