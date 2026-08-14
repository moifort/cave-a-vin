import { wineDetails } from '~/domain/beverage/business-rules'
import { normalizedForSearch, wordTokens } from './tokens'
import type { SearchableWine, SearchFilters, SearchHit, SearchMatchedField } from './types'
import { facetsOf, LONGEST_PHRASE } from './vocabulary'

// How many words from `index` a vocabulary entry covers, one when none does. The
// widest span wins: "vin jaune" is the yellow wine of the Jura, not the wine
// type followed by a colour.
const knownSpan = (words: string[], index: number) => {
  const widest = Math.min(LONGEST_PHRASE, words.length - index)
  for (let span = widest; span > 1; span--) {
    if (facetsOf(words.slice(index, index + span).join(' ')).length > 0) return span
  }
  return 1
}

// The query split into what has to be searched for as a whole. A word is a
// segment of its own, and the words a vocabulary entry spans travel together —
// "vendanges tardives" means nothing cut in two. Segment order carries no
// meaning: "margaux chateau" and "chateau margaux" search for the same two
// segments.
export const querySegments = (query: string) => {
  const words = normalizedForSearch(query)
    .split(/\s+/)
    .filter((word) => word.length > 0)
  const segments: string[] = []
  let index = 0
  while (index < words.length) {
    const span = knownSpan(words, index)
    segments.push(words.slice(index, index + span).join(' '))
    index += span
  }
  return segments
}

// How many bottles a segment is likely to bring back, narrowest first: a plain
// word is rarer than any category, a subtype rarer than a robe, a robe rarer
// than a beverage type.
const BREADTH = { subtype: 1, color: 2, type: 3 } as const
const breadth = (segment: string) => {
  const kinds = facetsOf(segment).map((facet) => facet.split(':')[0] as keyof typeof BREADTH)
  return kinds.length === 0 ? 0 : Math.min(...kinds.map((kind) => BREADTH[kind]))
}

// The one segment worth asking Firestore for: the narrowest, and among equals the
// longest, a long word being the rarer. Only one segment can reach the single
// array clause Firestore allows, so the choice is pure economy — every other
// segment is settled in memory either way.
export const narrowestSegment = (segments: string[]) =>
  segments.reduce((best, segment) => {
    if (breadth(segment) !== breadth(best)) return breadth(segment) < breadth(best) ? segment : best
    return segment.length > best.length ? segment : best
  })

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
// makes it, where it comes from, when, what kind of thing it is, and finally who
// it relates to. The three facet fields sit below region and appellation on
// purpose: a champagne is not a synonym for a sparkling wine, so on "champagne" a
// bottle from the Champagne region has to outrank a crémant that merely shares
// the kind.
const FIELD_WEIGHTS: Record<SearchMatchedField, number> = {
  name: 100,
  producer: 80,
  appellation: 60,
  region: 60,
  subtype: 55,
  color: 50,
  vintage: 50,
  'beverage-type': 45,
  'gifted-by': 40,
  'gift-recipient': 40,
  recommender: 40,
  'tasting-contact': 40,
}

// Every text field of the wine (and its satellites) a word is matched against,
// with the strength of that match. Contacts keep their best match only.
const textStrengths = (item: SearchableWine, token: string) => {
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

// The facets a segment designates, kept only when this bottle carries them. A
// facet is designated whole or not at all, so its strength is the exact-match 3:
// what holds it behind a real word is its weight, not its strength.
const facetStrengths = (item: SearchableWine, segment: string) => {
  const facets = facetsOf(segment)
  const strengths: [SearchMatchedField, number][] = []
  if (facets.length === 0) return strengths
  const color = wineDetails(item)?.color
  if (item.subtype !== undefined && facets.includes(`subtype:${item.subtype}`))
    strengths.push(['subtype', 3])
  if (color !== undefined && facets.includes(`color:${color}`)) strengths.push(['color', 3])
  if (facets.includes(`type:${item.beverageType}`)) strengths.push(['beverage-type', 3])
  return strengths
}

// Every way a segment can be answered: the wine's own words, and the facets the
// segment names. A word can do both — "champagne" names the kind and is written
// on the label of a Champagne Charlie.
const fieldStrengths = (item: SearchableWine, segment: string) => [
  ...textStrengths(item, segment),
  ...facetStrengths(item, segment),
]

// The hit a wine scores for a query, or null when one of the words found
// nothing. Every word must match some field (their order is free), and the score
// sums each word's best field, so a wine answering two words outranks one
// answering a single word twice over. A field matching the whole query exactly
// adds its weight again: an exact title beats a longer name that merely holds
// the same words. Single-word queries take no bonus, their word already is the
// whole query.
export const searchHit = (item: SearchableWine, query: string): SearchHit | null => {
  const tokens = querySegments(query)
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
  const tokens = querySegments(query)
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
