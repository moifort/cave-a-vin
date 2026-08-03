import type { Brand } from 'ts-brand'
import type {
  Country,
  Eur,
  Latitude,
  Longitude,
  Percentage,
  PlaceName,
  Region,
  UserId,
  Year,
} from '~/domain/shared/types'

export type BeverageId = Brand<string, 'BeverageId'>
export type BeverageName = Brand<string, 'BeverageName'>
export type Producer = Brand<string, 'Producer'>
export type Notes = Brand<string, 'Notes'>
// Beverage-scoped branded values.
export type Appellation = Brand<string, 'Appellation'>
export type Classification = Brand<string, 'Classification'>
export type GrapeVariety = Brand<string, 'GrapeVariety'>
export type Celsius = Brand<number, 'Celsius'>
export type WineColor = 'red' | 'white' | 'rosé'

// The discriminant of the beverage union.
export type BeverageType = 'wine' | 'spirit' | 'beer' | 'sake' | 'cider' | 'other'

// Type-scoped subtypes: a structured refinement of a beverageType. Each type
// owns its own set (an IPA can only sit on a beer). 'sparkling' is shared by
// wine and sake (saké pétillant); 'other' is the escape hatch everywhere.
export type WineSubtype =
  | 'sparkling'
  | 'sweet'
  | 'late-harvest'
  | 'vin-jaune'
  | 'porto'
  | 'fortified'
  | 'other'
export type SpiritSubtype =
  | 'rum'
  | 'whisky'
  | 'gin'
  | 'vodka'
  | 'cognac'
  | 'armagnac'
  | 'tequila'
  | 'liqueur'
  | 'eau-de-vie'
  | 'other'
export type BeerSubtype =
  | 'blonde'
  | 'blanche'
  | 'amber'
  | 'brune'
  | 'ipa'
  | 'stout'
  | 'pils'
  | 'triple'
  | 'other'
export type SakeSubtype =
  | 'junmai'
  | 'ginjo'
  | 'daiginjo'
  | 'honjozo'
  | 'nigori'
  | 'sparkling'
  | 'other'
export type CiderSubtype = 'brut' | 'doux' | 'demi-sec' | 'poire' | 'other'
export type OtherSubtype = 'other'
// The aggregate union of every subtype — used by the flat GraphQL enum, the Zod
// scan schema and the subtype/type validation table.
export type BeverageSubtype =
  | WineSubtype
  | SpiritSubtype
  | BeerSubtype
  | SakeSubtype
  | CiderSubtype
  | OtherSubtype

export type BeverageSort = 'createdAt' | 'updatedAt' | 'vintage' | 'region' | 'color' | 'price'
export type SortOrder = 'asc' | 'desc'
export type BeverageStatus = 'in-cellar' | 'consumed' | 'gifted' | 'recommended'
// Which view of the beverage list is shown, and an optional lifecycle filter on it.
export type BeverageListMode = 'all' | 'favorites' | 'gifted' | 'recommended'
export type BeverageStatusFilter = 'all' | 'in-cellar' | 'consumed'

// The years a wine is at its best — either bound may stand alone (a wine to
// drink "from 2028" with no upper bound, or "before 2030" with no lower one).
export type DrinkWindow = { from?: Year; until?: Year }

// Where the bottle was bought. A coordinate pair always travels together; the
// place name may exist without them (a shop typed by hand) and vice-versa.
export type Place = { latitude?: Latitude; longitude?: Longitude; name?: PlaceName }

// What the bottle cost and when it was acquired (a native Date, not a string).
export type Purchase = { price?: Eur; date?: Date }

// Fields that belong to a wine and to no other beverage type.
export type WineDetails = {
  color?: WineColor
  vintage?: Year
  appellation?: Appellation
  classification?: Classification
  grapeVarieties?: GrapeVariety[]
  drinkWindow?: DrinkWindow
  servingTemperature?: Celsius
}

// Fields shared by every beverage, whatever its type.
type BeverageBase = {
  id: BeverageId
  userId: UserId
  name: BeverageName
  alcoholContent?: Percentage
  producer?: Producer
  region?: Region
  country?: Country
  purchase?: Purchase
  notes?: Notes
  place?: Place
  /**
   * Every term this wine can be found by, written ahead of time so Firestore can
   * search it (see `server/domain/search/tokens.ts`). Optional: a wine written
   * before the index existed simply has none until it is reindexed.
   */
  searchIndex?: string[]
  createdAt: Date
  updatedAt: Date
}

// The discriminated union: the beverageType selects the member, each member
// carries its own type-scoped subtype, and only `wine` carries a details object.
export type BeverageVariant =
  | { beverageType: 'wine'; subtype?: WineSubtype; wine: WineDetails }
  | { beverageType: 'spirit'; subtype?: SpiritSubtype }
  | { beverageType: 'beer'; subtype?: BeerSubtype }
  | { beverageType: 'sake'; subtype?: SakeSubtype }
  | { beverageType: 'cider'; subtype?: CiderSubtype }
  | { beverageType: 'other'; subtype?: OtherSubtype }

export type Beverage = BeverageBase & BeverageVariant

// The write shape accepted by commands: the mutable base fields plus the
// variant-carried subtype and wine details. Identity/timestamps are set by the
// command, and beverageType is passed alongside (add) or merged in (update).
export type BeverageData = {
  alcoholContent?: Percentage
  producer?: Producer
  region?: Region
  country?: Country
  purchase?: Purchase
  notes?: Notes
  place?: Place
  subtype?: BeverageSubtype
  wine?: WineDetails
}
