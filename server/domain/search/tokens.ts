import { wineDetails } from '~/domain/beverage/business-rules'
import type { Beverage } from '~/domain/beverage/types'
import type { CellarBottleView } from '~/domain/cellar/types'
import type { Gift } from '~/domain/gift/types'
import type { Recommendation } from '~/domain/recommendation/types'
import type { UserId } from '~/domain/shared/types'
import type { TastingNote } from '~/domain/tasting/types'
import type { SearchFilters } from './types'

// Accent-, case- and separator-insensitive canonical form: "Château" matches
// "chateau", and the "vin-jaune"/"eau-de-vie" subtype codes match "vin jaune".
export const normalizedForSearch = (text: string) =>
  text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/-/g, ' ')
    .trim()

// Below this length a word is left alone: cutting a mark off a three-letter word
// would leave two letters, which match far too much.
const SHORTEST_WORD = 3

// A word reduced to the form both sides of the search agree on. The rule does
// not have to be linguistically right, only identical when writing and when
// searching: cutting the plural mark off "Margaux" gives "margau", and the
// query "margaux" is cut the same way, so they still meet. Kept deliberately
// blunt, a real French stemmer would maul appellations.
export const canonical = (word: string) => {
  const elided = word.includes("'") ? (word.split("'").pop() ?? word) : word
  const normalized = normalizedForSearch(elided)
  if (normalized.length <= SHORTEST_WORD) return normalized
  return /[sx]$/.test(normalized) ? normalized.slice(0, -1) : normalized
}

// Every prefix of a value from `shortest` characters up, longest first. Reserved
// for the vintage: a year is short and its prefixes are meaningful ("20" for the
// 2000s), where prefixing every word of every label would multiply the index by
// five to save the user the end of a word.
const withPrefixes = (value: string, shortest: number) => {
  const prefixes: string[] = []
  for (let length = value.length; length >= shortest; length--) {
    prefixes.push(value.slice(0, length))
  }
  return prefixes
}

// The searchable words of a free-text field, whole and canonical. A partially
// typed word matches nothing: `array-contains` tests equality, not prefix.
export const wordTokens = (text: string | undefined) => {
  if (!text) return []
  return normalizedForSearch(text)
    .split(/\s+/)
    .filter((word) => word.length > 0)
    .map((word) => canonical(word))
}

// People are namespaced by whoever recorded them: a housemate's tasting guests
// live on the same shared wine document, and must never surface in someone
// else's search.
const personTokens = (userId: UserId, name: string | undefined) =>
  wordTokens(name).map((token) => `p:${userId}:${token}`)

// A wine as the index sees it: not through one viewer's eyes but through every
// member's at once. A shared bottle carries one tasting note per person who
// wrote one, and each set of terms is namespaced with its author, so nobody's
// favourites leak into anybody else's search.
export type IndexableWine = Beverage & {
  cellar?: CellarBottleView
  consumption?: TastingNote[]
  gift?: Gift[]
  recommendation?: Recommendation[]
}

// Everything a wine can be found by. Free-text words carry no namespace; facets
// carry one so that "red" the colour never collides with "red" the word. Facets
// that belong to a person rather than to the wine are suffixed with their owner.
export const searchIndexOf = (wine: IndexableWine): string[] => {
  const details = wineDetails(wine)
  const tokens = [
    ...wordTokens(wine.name),
    ...wordTokens(wine.producer),
    ...wordTokens(wine.subtype),
    ...wordTokens(details?.appellation),
    ...wordTokens(wine.region),
    ...(details?.vintage === undefined ? [] : withPrefixes(String(details.vintage), 2)),
    `type:${wine.beverageType}`,
    ...(wine.subtype === undefined ? [] : [`subtype:${wine.subtype}`]),
    ...(details?.color === undefined ? [] : [`color:${details.color}`]),
    // The cellar is shared by the household, so its mark carries no owner.
    ...(wine.cellar === undefined ? [] : ['incellar']),
    ...(wine.consumption ?? []).flatMap((note) => [
      ...(note.favorite === true ? [`fav:${note.userId}`] : []),
      ...(note.consumedDate == null ? [] : [`consumed:${note.userId}`]),
      ...(note.contacts ?? []).flatMap((contact) => personTokens(note.userId, contact)),
    ]),
    ...(wine.gift ?? []).flatMap((gift) => [
      `gift:${gift.userId}`,
      ...personTokens(gift.userId, gift.received?.from),
      ...personTokens(gift.userId, gift.given?.recipientName),
    ]),
    ...(wine.recommendation ?? []).flatMap((recommendation) =>
      personTokens(recommendation.userId, recommendation.recommenderName),
    ),
  ]
  return [...new Set(tokens)]
}

// What a searched word is looked up as: the word itself, or the same word among
// the people the viewer recorded. Firestore takes both in one array-contains-any.
export const queryTerms = (token: string, viewerId: UserId) => {
  const word = canonical(token)
  return [word, `p:${viewerId}:${word}`]
}

// The facet Firestore is asked for when the query has no text, as the set of
// terms a matching wine may carry. The rarest facet first: a favourite is
// scarcer than a colour, which is scarcer than a beverage type. A facet holding
// several values rides along whole, since array-contains-any is a disjunction —
// exactly what "red or white" means. The remaining facets are settled in memory.
export const facetTerms = (filters: SearchFilters, viewerId: UserId): string[] => {
  if (filters.favorite === true) return [`fav:${viewerId}`]
  if (filters.gifted === true) return [`gift:${viewerId}`]
  if (filters.status === 'consumed') return [`consumed:${viewerId}`]
  if (filters.colors?.length) return filters.colors.map((color) => `color:${color}`)
  if (filters.status === 'in-cellar') return ['incellar']
  if (filters.beverageTypes?.length) return filters.beverageTypes.map((type) => `type:${type}`)
  return []
}
