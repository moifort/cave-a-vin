#!/usr/bin/env bun
/**
 * Fills a cellar worth photographing, against the local end-to-end stack.
 *
 * The screenshots the App Store and the README show cannot come from an empty
 * account: a wizard hands out a grid and nothing else, and a cellar with three
 * bottles sells nothing. This seeds one fixed account through the same public
 * API the app calls — no fixture file, no direct Firestore write — so a screen
 * that changes shape breaks this script rather than producing a lying picture.
 *
 * Talks to the Nitro server on :3000 backed by the Firebase emulators
 * (scripts/screenshots.sh starts all of it). The account is created in the Auth
 * emulator here, then the app signs in as the same one and finds the cellar.
 *
 * Usage: bun scripts/seed-screenshot-cellar.ts   (called by screenshots.sh)
 */

const AUTH_EMULATOR = process.env.SCREENSHOT_AUTH_EMULATOR ?? '127.0.0.1:9099'
const SERVER = process.env.SCREENSHOT_SERVER ?? 'http://127.0.0.1:3000'
/** Fixed, unlike the e2e accounts: the app has to sign into this very cellar. */
export const SCREENSHOT_ACCOUNT = 'screenshots@vinarium.test'
const PASSWORD = 'e2e-password'

const CELLAR = { rows: 6, cols: 8, zones: 2, firstName: 'Thibaut' }

/** A day count back from today, so the journal never shows a frozen date. */
const daysAgo = (days: number) => new Date(Date.now() - days * 86_400_000).toISOString()

type Bottle = {
  name: string
  producer?: string
  vintage?: number
  color?: 'RED' | 'WHITE' | 'ROSE'
  beverageType?: 'WINE' | 'BEER' | 'CIDER' | 'SAKE' | 'OTHER'
  subtype?: string
  region?: string
  country?: string
  appellation?: string
  grapeVarieties?: string[]
  drinkFrom?: number
  drinkUntil?: number
  purchasePrice?: number
  alcoholContent?: number
  /** Where it sits in the grid. Absent means the bottle is out of the cellar. */
  at?: { row: number; col: number }
  /** Where the bottle was found, which the detail screen shows on a map. */
  discoveredAt?: { latitude: number; longitude: number; placeName: string }
  favorite?: boolean
  /** A tasting note kept on a bottle still in the cellar. */
  tasting?: { rating: number; notes: string; daysAgo: number }
  /** A bottle drunk: it leaves the grid and lands in the journal. */
  drunk?: { rating: number; notes: string; daysAgo: number; contacts?: string[] }
}

// A cellar that reads like someone's, not like a fixture: a spread of regions
// and colours, a few whites and a rosé among the reds, prices that make the
// total credible, and drink windows that put some bottles at their peak so the
// dashboard has something to say.
const BOTTLES: Bottle[] = [
  // Out of the grid, in the journal: what the app remembers of what is gone.
  // Seeded first so the wine list, which sorts newest first, never opens on a
  // bottle that is already drunk.
  {
    name: 'Pauillac Les Forts de Latour',
    producer: 'Château Latour',
    vintage: 2014,
    color: 'RED',
    region: 'Bordeaux',
    country: 'France',
    appellation: 'Pauillac',
    grapeVarieties: ['Cabernet Sauvignon', 'Merlot'],
    purchasePrice: 175,
    drunk: {
      rating: 5,
      notes: 'Ouvert pour les 40 ans de Marie. Cassis, cèdre, tanins encore serrés.',
      daysAgo: 12,
      contacts: ['Marie'],
    },
  },
  {
    name: 'Condrieu La Doriane',
    producer: 'E. Guigal',
    vintage: 2021,
    color: 'WHITE',
    region: 'Vallée du Rhône',
    country: 'France',
    appellation: 'Condrieu',
    grapeVarieties: ['Viognier'],
    purchasePrice: 88,
    drunk: {
      rating: 4,
      notes: 'Abricot, fleur blanche. Servi sur un poisson en sauce, très juste.',
      daysAgo: 26,
    },
  },
  {
    name: 'Morgon Côte du Py',
    producer: 'Jean Foillard',
    vintage: 2022,
    color: 'RED',
    region: 'Beaujolais',
    country: 'France',
    appellation: 'Morgon',
    grapeVarieties: ['Gamay'],
    purchasePrice: 29,
    drunk: {
      rating: 4,
      notes: 'Croquant, gourmand. Le genre de bouteille qui part vite.',
      daysAgo: 47,
    },
  },
  {
    name: 'Gevrey-Chambertin',
    producer: 'Domaine Armand Rousseau',
    vintage: 2019,
    color: 'RED',
    region: 'Bourgogne',
    country: 'France',
    appellation: 'Gevrey-Chambertin',
    grapeVarieties: ['Pinot Noir'],
    drinkFrom: 2024,
    drinkUntil: 2035,
    purchasePrice: 145,
    alcoholContent: 13,
    at: { row: 0, col: 1 },
    tasting: {
      rating: 5,
      notes: 'Cerise noire, sous-bois, une longueur remarquable.',
      daysAgo: 40,
    },
  },
  {
    name: 'Chablis Grand Cru Les Clos',
    producer: 'William Fèvre',
    vintage: 2020,
    color: 'WHITE',
    region: 'Bourgogne',
    country: 'France',
    appellation: 'Chablis Grand Cru',
    grapeVarieties: ['Chardonnay'],
    drinkFrom: 2023,
    drinkUntil: 2032,
    purchasePrice: 89,
    alcoholContent: 13,
    at: { row: 0, col: 2 },
  },
  {
    name: 'Côte-Rôtie La Landonne',
    producer: 'E. Guigal',
    vintage: 2017,
    color: 'RED',
    region: 'Vallée du Rhône',
    country: 'France',
    appellation: 'Côte-Rôtie',
    grapeVarieties: ['Syrah'],
    drinkFrom: 2027,
    drinkUntil: 2050,
    purchasePrice: 320,
    at: { row: 0, col: 3 },
  },
  {
    name: 'Sancerre Les Monts Damnés',
    producer: 'Vacheron',
    vintage: 2022,
    color: 'WHITE',
    region: 'Loire',
    country: 'France',
    appellation: 'Sancerre',
    grapeVarieties: ['Sauvignon Blanc'],
    drinkFrom: 2024,
    drinkUntil: 2029,
    purchasePrice: 42,
    at: { row: 1, col: 0 },
  },
  {
    name: 'Barolo Cannubi',
    producer: 'Damilano',
    vintage: 2018,
    color: 'RED',
    region: 'Piémont',
    country: 'Italie',
    appellation: 'Barolo',
    grapeVarieties: ['Nebbiolo'],
    drinkFrom: 2026,
    drinkUntil: 2040,
    purchasePrice: 78,
    at: { row: 1, col: 1 },
  },
  {
    name: 'Rioja Gran Reserva 904',
    producer: 'La Rioja Alta',
    vintage: 2011,
    color: 'RED',
    region: 'Rioja',
    country: 'Espagne',
    grapeVarieties: ['Tempranillo', 'Graciano'],
    drinkFrom: 2022,
    drinkUntil: 2033,
    purchasePrice: 62,
    at: { row: 1, col: 2 },
    favorite: true,
  },
  {
    name: 'Bandol Rosé',
    producer: 'Domaine Tempier',
    vintage: 2023,
    color: 'ROSE',
    region: 'Provence',
    country: 'France',
    appellation: 'Bandol',
    grapeVarieties: ['Mourvèdre', 'Grenache'],
    drinkFrom: 2024,
    drinkUntil: 2027,
    purchasePrice: 34,
    at: { row: 1, col: 3 },
  },
  {
    name: 'Riesling Clos Sainte-Hune',
    producer: 'Trimbach',
    vintage: 2016,
    color: 'WHITE',
    region: 'Alsace',
    country: 'France',
    grapeVarieties: ['Riesling'],
    drinkFrom: 2024,
    drinkUntil: 2040,
    purchasePrice: 165,
    at: { row: 2, col: 0 },
  },
  {
    name: 'Châteauneuf-du-Pape',
    producer: 'Château de Beaucastel',
    vintage: 2019,
    color: 'RED',
    region: 'Vallée du Rhône',
    country: 'France',
    appellation: 'Châteauneuf-du-Pape',
    grapeVarieties: ['Grenache', 'Mourvèdre', 'Syrah'],
    drinkFrom: 2025,
    drinkUntil: 2042,
    purchasePrice: 98,
    at: { row: 2, col: 1 },
  },
  {
    name: 'Pouilly-Fuissé Les Crays',
    producer: 'Château des Rontets',
    vintage: 2021,
    color: 'WHITE',
    region: 'Bourgogne',
    country: 'France',
    appellation: 'Pouilly-Fuissé',
    grapeVarieties: ['Chardonnay'],
    drinkFrom: 2023,
    drinkUntil: 2030,
    purchasePrice: 48,
    at: { row: 2, col: 2 },
  },
  {
    name: 'Brunello di Montalcino',
    producer: 'Biondi-Santi',
    vintage: 2016,
    color: 'RED',
    region: 'Toscane',
    country: 'Italie',
    appellation: 'Brunello di Montalcino',
    grapeVarieties: ['Sangiovese'],
    drinkFrom: 2026,
    drinkUntil: 2046,
    purchasePrice: 210,
    at: { row: 2, col: 3 },
  },
  {
    name: 'Vouvray Moelleux',
    producer: 'Domaine Huet',
    vintage: 2018,
    color: 'WHITE',
    region: 'Loire',
    country: 'France',
    appellation: 'Vouvray',
    grapeVarieties: ['Chenin Blanc'],
    drinkFrom: 2025,
    drinkUntil: 2050,
    purchasePrice: 56,
    at: { row: 3, col: 0 },
  },
  {
    name: 'Saint-Émilion Grand Cru',
    producer: 'Château Canon',
    vintage: 2016,
    color: 'RED',
    region: 'Bordeaux',
    country: 'France',
    appellation: 'Saint-Émilion Grand Cru',
    grapeVarieties: ['Merlot', 'Cabernet Franc'],
    drinkFrom: 2024,
    drinkUntil: 2040,
    purchasePrice: 130,
    at: { row: 3, col: 1 },
  },
  {
    name: 'Meursault Les Charmes',
    producer: 'Domaine Roulot',
    vintage: 2020,
    color: 'WHITE',
    region: 'Bourgogne',
    country: 'France',
    appellation: 'Meursault 1er Cru',
    grapeVarieties: ['Chardonnay'],
    drinkFrom: 2025,
    drinkUntil: 2035,
    purchasePrice: 240,
    at: { row: 3, col: 2 },
    favorite: true,
  },
  {
    name: 'Cornas Reynard',
    producer: 'Thierry Allemand',
    vintage: 2017,
    color: 'RED',
    region: 'Vallée du Rhône',
    country: 'France',
    appellation: 'Cornas',
    grapeVarieties: ['Syrah'],
    drinkFrom: 2026,
    drinkUntil: 2045,
    purchasePrice: 290,
    at: { row: 3, col: 3 },
  },
  {
    name: 'Champagne Blanc de Blancs',
    producer: 'Pierre Péters',
    vintage: 2017,
    color: 'WHITE',
    region: 'Champagne',
    country: 'France',
    appellation: 'Champagne Grand Cru',
    grapeVarieties: ['Chardonnay'],
    drinkFrom: 2024,
    drinkUntil: 2032,
    purchasePrice: 92,
    at: { row: 4, col: 0 },
  },
  {
    name: 'Priorat Clos Mogador',
    producer: 'René Barbier',
    vintage: 2018,
    color: 'RED',
    region: 'Priorat',
    country: 'Espagne',
    grapeVarieties: ['Garnacha', 'Cariñena'],
    drinkFrom: 2025,
    drinkUntil: 2038,
    purchasePrice: 85,
    at: { row: 4, col: 1 },
  },
  // Seeded last, and the most complete record of the lot: the wine list sorts
  // newest first, so this is the bottle the detail screenshot opens on. Every
  // section the screen can show is filled — drink window, origin, discovery
  // place, price, grapes — because an empty section photographs as a gap.
  {
    name: 'Château Margaux',
    producer: 'Château Margaux',
    vintage: 2015,
    color: 'RED',
    region: 'Bordeaux',
    country: 'France',
    appellation: 'Margaux',
    grapeVarieties: ['Cabernet Sauvignon', 'Merlot'],
    drinkFrom: 2025,
    drinkUntil: 2045,
    purchasePrice: 690,
    alcoholContent: 13.5,
    at: { row: 0, col: 0 },
    favorite: true,
    discoveredAt: { latitude: 45.0353, longitude: -0.6708, placeName: 'Margaux-Cantenac' },
  },
]

let token = ''

/** Signs the fixed account into the Auth emulator, creating it on first run. */
const authenticate = async (): Promise<string> => {
  const base = `http://${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts`
  const body = JSON.stringify({
    email: SCREENSHOT_ACCOUNT,
    password: PASSWORD,
    returnSecureToken: true,
  })
  const options = { method: 'POST', headers: { 'Content-Type': 'application/json' }, body }
  // The emulator accepts any API key; it verifies nothing.
  const signUp = await fetch(`${base}:signUp?key=fake-api-key`, options)
  if (signUp.ok) return ((await signUp.json()) as { idToken: string }).idToken
  const signIn = await fetch(`${base}:signInWithPassword?key=fake-api-key`, options)
  if (!signIn.ok) throw new Error(`auth emulator refused the account: ${await signIn.text()}`)
  return ((await signIn.json()) as { idToken: string }).idToken
}

const graphql = async <T>(query: string, variables: Record<string, unknown> = {}): Promise<T> => {
  const response = await fetch(`${SERVER}/graphql`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ query, variables }),
  })
  const payload = (await response.json()) as { data?: T; errors?: { message: string }[] }
  if (payload.errors?.length) throw new Error(payload.errors.map((e) => e.message).join(' / '))
  if (!payload.data) throw new Error(`no data for ${query.slice(0, 40)}…`)
  return payload.data
}

const onboard = () =>
  graphql(
    `mutation ($input: CompleteOnboardingInput!) { completeOnboarding(input: $input) { firstName } }`,
    { input: CELLAR },
  )

const addBottle = async (bottle: Bottle): Promise<string> => {
  const { at, favorite, tasting, drunk, discoveredAt, ...input } = bottle
  const data = await graphql<{ addBeverage: { id: string } }>(
    `mutation ($input: AddBeverageInput!) { addBeverage(input: $input) { id } }`,
    { input: { beverageType: 'WINE', ...input, ...discoveredAt } },
  )
  return data.addBeverage.id
}

const place = (beverageId: string, row: number, col: number) =>
  graphql(
    `mutation ($id: BeverageId!, $row: Int!, $col: Int!) {
      placeBottle(beverageId: $id, row: $row, col: $col) { rowLabel colLabel }
    }`,
    {
      id: beverageId,
      row,
      col,
    },
  )

const favorite = (beverageId: string) =>
  graphql(`mutation ($id: BeverageId!) { markFavorite(beverageId: $id, favorite: true) }`, {
    id: beverageId,
  })

const taste = (beverageId: string, input: Record<string, unknown>) =>
  graphql(
    `mutation ($id: BeverageId!, $input: TastingInput!) { recordTasting(beverageId: $id, input: $input) }`,
    {
      id: beverageId,
      input,
    },
  )

const drink = (beverageId: string, input: Record<string, unknown>) =>
  graphql(
    `mutation ($id: BeverageId!, $input: ConsumptionInput!) { consumeBottle(beverageId: $id, input: $input) }`,
    {
      id: beverageId,
      input,
    },
  )

const main = async () => {
  token = await authenticate()
  await onboard()

  let placed = 0
  let drunkCount = 0
  for (const bottle of BOTTLES) {
    const id = await addBottle(bottle)
    if (bottle.at) {
      await place(id, bottle.at.row, bottle.at.col)
      placed += 1
    }
    if (bottle.favorite) await favorite(id)
    if (bottle.tasting)
      await taste(id, {
        rating: bottle.tasting.rating,
        tastingNotes: bottle.tasting.notes,
        consumedDate: daysAgo(bottle.tasting.daysAgo),
      })
    if (bottle.drunk) {
      // A drunk bottle has to be placed first: the journal records an exit, and
      // there is nothing to exit from until the bottle sits somewhere.
      await place(id, 5, drunkCount)
      await drink(id, {
        rating: bottle.drunk.rating,
        tastingNotes: bottle.drunk.notes,
        consumedDate: daysAgo(bottle.drunk.daysAgo),
        contacts: bottle.drunk.contacts ?? [],
      })
      drunkCount += 1
    }
  }

  console.log(
    `Seeded ${SCREENSHOT_ACCOUNT}: ${placed} bottles in the grid, ${drunkCount} in the journal.`,
  )
}

await main()
