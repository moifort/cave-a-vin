import type {
  Beverage,
  BeverageStatusFilter,
  BeverageType,
  WineColor,
} from '~/domain/beverage/types'
import type { CellarBottleView } from '~/domain/cellar/types'
import type { Gift } from '~/domain/gift/types'
import type { Recommendation } from '~/domain/recommendation/types'
import type { TastingNote } from '~/domain/tasting/types'

// A wine joined with its satellites, ready for matching. A wine without a
// satellite simply has no key for it — the object carries what exists, nothing
// else. The GraphQL layer never reads these: its satellite fields resolve
// through the per-request loaders, whose reads the search scans already warmed.
export type SearchableWine = Beverage & {
  cellar?: CellarBottleView
  consumption?: TastingNote
  gift?: Gift
  recommendation?: Recommendation
}

// Which wine attribute matched the query — the client groups results by it
// (a person match reads "gift", a name match reads "wine").
export type SearchMatchedField =
  | 'name'
  | 'producer'
  | 'subtype'
  | 'color'
  | 'beverage-type'
  | 'appellation'
  | 'region'
  | 'vintage'
  | 'gifted-by'
  | 'gift-recipient'
  | 'recommender'
  | 'tasting-contact'

// Facet filters combinable with the text query. Only `true` activates the
// boolean facets; `false`/undefined means "not filtered on".
export type SearchFilters = {
  colors?: WineColor[]
  beverageTypes?: BeverageType[]
  favorite?: boolean
  status?: BeverageStatusFilter
  gifted?: boolean
}

export type SearchHit = {
  item: SearchableWine
  matchedFields: SearchMatchedField[]
  score: number
}
