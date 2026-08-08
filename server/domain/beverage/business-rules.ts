import {
  BEER_SUBTYPES,
  CIDER_SUBTYPES,
  OTHER_SUBTYPES,
  SAKE_SUBTYPES,
  SPIRIT_SUBTYPES,
  WINE_SUBTYPES,
} from '~/domain/beverage/primitives'
import type {
  Beverage,
  BeverageStatus,
  BeverageSubtype,
  BeverageType,
  ErasableField,
  WineDetails,
} from '~/domain/beverage/types'

// Years as plain numbers: the drink-window rules are pure arithmetic, decoupled
// from the branded Year of the aggregate (a Year is assignable to number).
type YearRange = { from?: number; until?: number }

// Where each erasable field lives in the stored document. A write model that
// nests (purchase, place, wine, drinkWindow) still has to answer a flat "empty
// this one".
const fieldLocation: Record<ErasableField, readonly string[]> = {
  alcoholContent: ['alcoholContent'],
  producer: ['producer'],
  region: ['region'],
  country: ['country'],
  notes: ['notes'],
  subtype: ['subtype'],
  purchasePrice: ['purchase', 'price'],
  purchaseDate: ['purchase', 'date'],
  latitude: ['place', 'latitude'],
  longitude: ['place', 'longitude'],
  placeName: ['place', 'name'],
  color: ['wine', 'color'],
  vintage: ['wine', 'vintage'],
  appellation: ['wine', 'appellation'],
  classification: ['wine', 'classification'],
  grapeVarieties: ['wine', 'grapeVarieties'],
  servingTemperature: ['wine', 'servingTemperature'],
  drinkFrom: ['wine', 'drinkWindow', 'from'],
  drinkUntil: ['wine', 'drinkWindow', 'until'],
}

// Remove the named fields from a record, then drop the containers they leave
// empty: a purchase with neither price nor date is no purchase at all, and an
// empty object read back as `{}` would make the API answer a hollow node.
export const withoutFields = <T extends Record<string, unknown>>(
  record: T,
  fields: readonly ErasableField[],
): T => {
  if (fields.length === 0) return record
  const copy = structuredClone(record) as Record<string, unknown>
  for (const field of fields) {
    const path = fieldLocation[field]
    const parent = path.slice(0, -1).reduce<Record<string, unknown> | undefined>((node, key) => {
      const child = node?.[key]
      return child && typeof child === 'object' ? (child as Record<string, unknown>) : undefined
    }, copy)
    if (parent) delete parent[path[path.length - 1] as string]
  }
  pruneEmptyContainers(copy)
  return copy as T
}

// A wine always keeps its `wine` object (the type demands it); every other
// container disappears once it holds nothing.
const pruneEmptyContainers = (record: Record<string, unknown>) => {
  const wine = record.wine as Record<string, unknown> | undefined
  if (wine && isEmpty(wine.drinkWindow)) delete wine.drinkWindow
  for (const key of ['purchase', 'place'] as const) {
    if (isEmpty(record[key])) delete record[key]
  }
}

const isEmpty = (value: unknown) =>
  typeof value === 'object' && value !== null && Object.keys(value).length === 0

export const beverageStatus = (context: {
  inCellar: boolean
  gifted: boolean
  recommended: boolean
}): BeverageStatus => {
  if (context.inCellar) return 'in-cellar'
  if (context.gifted) return 'gifted'
  if (context.recommended) return 'recommended'
  return 'consumed'
}

export const readyToDrink = (window: YearRange, year: number) => {
  if (!window.from && !window.until) return false
  return (!window.from || window.from <= year) && (!window.until || window.until >= year)
}

export const urgentToDrink = (window: YearRange, year: number) => {
  if (!window.until) return false
  return window.until <= year + 1
}

// A wine is the only type that must declare its color.
export const requiresColor = (beverageType: BeverageType) => beverageType === 'wine'

// The wine-only details of a beverage, or undefined for any other type. Lets
// read models reach color/vintage/drinkWindow without re-narrowing the union.
export const wineDetails = (beverage: Beverage): WineDetails | undefined =>
  beverage.beverageType === 'wine' ? beverage.wine : undefined

// Which subtype values make sense for each beverage type — derived from the
// per-type sets in primitives.ts. 'sparkling' is shared by wine and sake (saké
// pétillant); 'other' is the escape hatch everywhere. Mirrored in iOS
// BeverageSubtype.allowed(for:) — keep both in sync.
export const SUBTYPES_BY_BEVERAGE: Record<BeverageType, readonly BeverageSubtype[]> = {
  wine: WINE_SUBTYPES,
  spirit: SPIRIT_SUBTYPES,
  beer: BEER_SUBTYPES,
  sake: SAKE_SUBTYPES,
  cider: CIDER_SUBTYPES,
  other: OTHER_SUBTYPES,
}

export const subtypeAllowed = (beverageType: BeverageType, subtype: BeverageSubtype) =>
  SUBTYPES_BY_BEVERAGE[beverageType].includes(subtype)

// When a beverage changes type, an inherited subtype survives only if it still
// makes sense: a sparkling wine turned sake stays sparkling, a beer turned wine
// loses its IPA.
export const retainedSubtype = (
  beverageType: BeverageType,
  subtype?: BeverageSubtype,
): BeverageSubtype | undefined =>
  subtype !== undefined && subtypeAllowed(beverageType, subtype) ? subtype : undefined
