import { wineDetails } from '~/domain/beverage/business-rules'
import { normalizedForSearch, wordTokens } from './tokens'
import type { SearchableWine, SearchFilters, SearchHit, SearchMatchedField } from './types'

// The query split into words. Word order carries no meaning: "margaux chateau"
// and "chateau margaux" search for the same two words.
export const queryTokens = (query: string) =>
  normalizedForSearch(query)
    .split(/\s+/)
    .filter((token) => token.length > 0)

// How strongly a candidate text matches a searched word: an exact match beats a
// prefix match, which beats a mere substring. Zero means no match.
//
// Both sides are compared in the canonical form the index is written in, so a
// word found through Firestore is not then rejected here over a plural mark:
// "chateaux" has to keep matching "Château" once the index handed the wine over.
export const matchStrength = (candidate: string | undefined, query: string) => {
  if (!candidate || !query) return 0
  const canonicalCandidate = wordTokens(candidate).join(' ')
  const canonicalQuery = wordTokens(query).join(' ')
  if (!canonicalQuery) return 0
  if (canonicalCandidate === canonicalQuery) return 3
  if (canonicalCandidate.startsWith(canonicalQuery)) return 2
  if (canonicalCandidate.includes(canonicalQuery)) return 1
  return 0
}

// A vintage only matches a numeric query, by year prefix ("20" finds 2015 and
// 2020, "bordeaux" never does). Substring matches would be noise ("015" → 2015).
export const vintageStrength = (vintage: number | undefined, query: string) => {
  if (vintage === undefined || !/^\d+$/.test(query)) return 0
  const year = String(vintage)
  if (year === query) return 3
  if (year.startsWith(query)) return 2
  return 0
}

// What the search result should surface first: the wine itself (name), then who
// makes it, what it is, where it comes from, when, and finally who it relates to.
const FIELD_WEIGHTS: Record<SearchMatchedField, number> = {
  name: 100,
  producer: 80,
  subtype: 70,
  appellation: 60,
  region: 60,
  vintage: 50,
  'gifted-by': 40,
  'gift-recipient': 40,
  recommender: 40,
  'tasting-contact': 40,
}

// Every field of the wine (and its satellites) a word is matched against, with
// the strength of that match. Contacts keep their best match only.
const fieldStrengths = (item: SearchableWine, token: string) => {
  const contacts = item.consumption?.contacts ?? []
  const details = wineDetails(item)
  const strengths: [SearchMatchedField, number][] = [
    ['name', matchStrength(item.name, token)],
    ['producer', matchStrength(item.producer, token)],
    ['subtype', matchStrength(item.subtype, token)],
    ['appellation', matchStrength(details?.appellation, token)],
    ['region', matchStrength(item.region, token)],
    ['vintage', vintageStrength(details?.vintage, token)],
    ['gifted-by', matchStrength(item.gift?.received?.from, token)],
    ['gift-recipient', matchStrength(item.gift?.given?.recipientName, token)],
    ['recommender', matchStrength(item.recommendation?.recommenderName, token)],
    ['tasting-contact', Math.max(0, ...contacts.map((contact) => matchStrength(contact, token)))],
  ]
  return strengths.filter(([, strength]) => strength > 0)
}

// The hit a wine scores for a query, or null when one of the words found
// nothing. Every word must match some field (their order is free), and the score
// sums each word's best field, so a wine answering two words outranks one
// answering a single word twice over. A field matching the whole query exactly
// adds its weight again: an exact title beats a longer name that merely holds
// the same words. Single-word queries take no bonus, their word already is the
// whole query.
export const searchHit = (item: SearchableWine, query: string): SearchHit | null => {
  const tokens = queryTokens(query)
  if (tokens.length === 0) return null
  const matchedFields: SearchMatchedField[] = []
  let score = 0
  for (const token of tokens) {
    const strengths = fieldStrengths(item, token)
    if (strengths.length === 0) return null
    for (const [field] of strengths) if (!matchedFields.includes(field)) matchedFields.push(field)
    score += Math.max(...strengths.map(([field, strength]) => FIELD_WEIGHTS[field] * strength))
  }
  if (tokens.length > 1) {
    const whole = fieldStrengths(item, normalizedForSearch(query))
    score += Math.max(0, ...whole.map(([field, strength]) => FIELD_WEIGHTS[field] * strength))
  }
  return { item, matchedFields, score }
}

export const passesFilters = (item: SearchableWine, filters: SearchFilters) => {
  const color = wineDetails(item)?.color
  if (filters.colors?.length && (!color || !filters.colors.includes(color))) return false
  if (filters.beverageTypes?.length && !filters.beverageTypes.includes(item.beverageType))
    return false
  if (filters.favorite === true && item.consumption?.favorite !== true) return false
  if (filters.status === 'in-cellar' && item.cellar === undefined) return false
  if (filters.status === 'consumed' && item.consumption?.consumedDate == null) return false
  if (filters.gifted === true && item.gift === undefined) return false
  return true
}

export const hasActiveFilters = (filters: SearchFilters) =>
  Boolean(filters.colors?.length) ||
  Boolean(filters.beverageTypes?.length) ||
  filters.favorite === true ||
  filters.status === 'in-cellar' ||
  filters.status === 'consumed' ||
  filters.gifted === true

// The full search: filter by facets, match the query, rank by relevance
// (score, then name for a stable order). An empty query browses by filters
// alone (name order, no matched fields); with no filter either, nothing is
// searched — the client shows its suggestions instead.
export const rankedHits = (
  items: SearchableWine[],
  query: string,
  filters: SearchFilters,
): SearchHit[] => {
  const tokens = queryTokens(query)
  const filtered = items.filter((item) => passesFilters(item, filters))
  const byName = (a: SearchableWine, b: SearchableWine) => a.name.localeCompare(b.name)
  if (tokens.length === 0) {
    if (!hasActiveFilters(filters)) return []
    return filtered
      .toSorted(byName)
      .map((item) => ({ item, matchedFields: [] as SearchMatchedField[], score: 0 }))
  }
  return filtered
    .map((item) => searchHit(item, query))
    .filter((hit): hit is SearchHit => hit !== null)
    .toSorted((a, b) => b.score - a.score || byName(a.item, b.item))
}
