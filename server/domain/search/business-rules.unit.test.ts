import { describe, expect, test } from 'bun:test'
import {
  hasActiveFilters,
  matchStrength,
  normalizedForSearch,
  passesFilters,
  queryTokens,
  rankedHits,
  searchHit,
  vintageStrength,
} from '~/domain/search/business-rules'
import type { SearchableWine } from '~/domain/search/types'

// Satellites are attached only when present — a bare wine carries no such keys.
// Wine-only overrides (color, vintage, appellation ...) are routed into the
// nested `wine` details; everything else stays at the top level.
const WINE_DETAIL_KEYS = [
  'color',
  'vintage',
  'appellation',
  'classification',
  'grapeVarieties',
  'drinkWindow',
  'servingTemperature',
]
const aWine = (overrides: Record<string, unknown> = {}): SearchableWine => {
  const wine: Record<string, unknown> = {}
  const base: Record<string, unknown> = {}
  for (const [key, value] of Object.entries(overrides)) {
    if (WINE_DETAIL_KEYS.includes(key)) wine[key] = value
    else base[key] = value
  }
  const beverageType = (base.beverageType as string) ?? 'wine'
  return {
    id: 'w1',
    userId: 'user-1',
    name: 'Château Margaux',
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    ...base,
    beverageType,
    ...(beverageType === 'wine' ? { wine } : {}),
  } as SearchableWine
}

describe('normalizedForSearch', () => {
  test('lowercases and strips accents', () => {
    expect(normalizedForSearch('Château Pétrus')).toBe('chateau petrus')
  })

  test('trims surrounding whitespace', () => {
    expect(normalizedForSearch('  margaux  ')).toBe('margaux')
  })

  test('treats hyphens as spaces so composite subtype codes match natural text', () => {
    expect(normalizedForSearch('vin-jaune')).toBe('vin jaune')
    expect(normalizedForSearch('eau-de-vie')).toBe('eau de vie')
  })
})

describe('queryTokens', () => {
  test('splits the normalized query into words', () => {
    expect(queryTokens('Château  Margaux')).toEqual(['chateau', 'margaux'])
  })

  test('a blank query has no word', () => {
    expect(queryTokens('   ')).toEqual([])
  })
})

describe('matchStrength', () => {
  test('exact match is strongest', () => {
    expect(matchStrength('Margaux', 'margaux')).toBe(3)
  })

  test('exact match ignores accents both ways', () => {
    expect(matchStrength('Château', 'château')).toBe(3)
    expect(matchStrength('chateau', 'Château')).toBe(3)
  })

  test('prefix match beats substring', () => {
    expect(matchStrength('Margaux du Sud', 'margaux')).toBe(2)
    expect(matchStrength('Château Margaux', 'margaux')).toBe(1)
  })

  test('no match yields zero', () => {
    expect(matchStrength('Margaux', 'petrus')).toBe(0)
  })

  test('missing candidate or empty query yields zero', () => {
    expect(matchStrength(undefined, 'margaux')).toBe(0)
    expect(matchStrength('Margaux', '')).toBe(0)
  })
})

describe('vintageStrength', () => {
  test('exact year matches', () => {
    expect(vintageStrength(2015, '2015')).toBe(3)
  })

  test('year prefix matches', () => {
    expect(vintageStrength(2015, '20')).toBe(2)
  })

  test('non-prefix digits never match', () => {
    expect(vintageStrength(2015, '015')).toBe(0)
  })

  test('non-numeric query never matches', () => {
    expect(vintageStrength(2015, 'bordeaux')).toBe(0)
  })

  test('missing vintage never matches', () => {
    expect(vintageStrength(undefined, '2015')).toBe(0)
  })
})

describe('searchHit', () => {
  test('null when nothing matches', () => {
    expect(searchHit(aWine(), 'petrus')).toBeNull()
  })

  test('collects every matched field', () => {
    const wine = aWine({
      name: 'Margaux',
      gift: { userId: 'user-1', beverageId: 'w1', received: { from: 'Margaux' } },
      consumption: { userId: 'user-1', beverageId: 'w1', contacts: ['Margaux Dupont'] },
    })
    const hit = searchHit(wine, 'margaux')
    expect(hit?.matchedFields).toEqual(['name', 'gifted-by', 'tasting-contact'])
  })

  test('every word must match, whatever the order', () => {
    const wine = aWine({ name: 'Château Margaux', region: 'Bordeaux' })
    expect(searchHit(wine, 'margaux chateau')?.matchedFields).toEqual(['name'])
    expect(searchHit(wine, 'chateau bordeaux')?.matchedFields).toEqual(['name', 'region'])
    expect(searchHit(wine, 'chateau petrus')).toBeNull()
  })

  test('a word on the vintage combines with a word on the name', () => {
    const wine = aWine({ name: 'Margaux', vintage: 2015 })
    expect(searchHit(wine, 'margaux 2015')?.matchedFields).toEqual(['name', 'vintage'])
  })

  test('each word contributes its best field to the score', () => {
    // 'margaux' matches the name exactly (100 x 3), 'chateau' prefixes the producer (80 x 2).
    const wine = aWine({ name: 'Margaux', producer: 'Château Latour' })
    expect(searchHit(wine, 'chateau margaux')?.score).toBe(460)
  })

  test('score keeps the single best weighted match', () => {
    const exactName = searchHit(aWine({ name: 'Margaux' }), 'margaux')
    const containsName = searchHit(aWine({ name: 'Château Margaux' }), 'margaux')
    expect(exactName?.score).toBe(300)
    expect(containsName?.score).toBe(100)
  })

  test('name outranks producer, producer outranks person, at equal strength', () => {
    const name = searchHit(aWine({ name: 'Margaux' }), 'margaux')?.score ?? 0
    const producer = searchHit(aWine({ producer: 'Margaux' }), 'margaux')?.score ?? 0
    const person =
      searchHit(
        aWine({ gift: { userId: 'user-1', beverageId: 'w1', received: { from: 'Margaux' } } }),
        'margaux',
      )?.score ?? 0
    expect(name).toBeGreaterThan(producer)
    expect(producer).toBeGreaterThan(person)
  })

  test('matches subtype, appellation, region and vintage', () => {
    const wine = aWine({
      subtype: 'porto',
      appellation: 'Porto DOC',
      region: 'Porto',
      vintage: 2015,
    })
    expect(searchHit(wine, 'porto')?.matchedFields).toEqual(['subtype', 'appellation', 'region'])
    expect(searchHit(wine, '2015')?.matchedFields).toEqual(['vintage'])
  })

  test('matches a composite subtype code from natural text', () => {
    const wine = aWine({ subtype: 'vin-jaune' })
    expect(searchHit(wine, 'vin jaune')?.matchedFields).toEqual(['subtype'])
  })

  test('matches gift recipient and recommender', () => {
    const wine = aWine({
      gift: {
        userId: 'user-1',
        beverageId: 'w1',
        given: { date: new Date(), recipientName: 'Alice' },
      },
      recommendation: { userId: 'user-1', beverageId: 'w1', recommenderName: 'Alicia' },
    })
    expect(searchHit(wine, 'alic')?.matchedFields).toEqual(['gift-recipient', 'recommender'])
  })

  test('best contact wins among several', () => {
    const wine = aWine({
      consumption: { userId: 'user-1', beverageId: 'w1', contacts: ['Bob Martin', 'Alice'] },
    })
    expect(searchHit(wine, 'alice')?.score).toBe(120)
  })
})

describe('passesFilters', () => {
  test('empty filters pass everything', () => {
    expect(passesFilters(aWine(), {})).toBe(true)
  })

  test('color filter needs the wine color in the list', () => {
    expect(passesFilters(aWine({ color: 'red' }), { colors: ['red', 'white'] })).toBe(true)
    expect(passesFilters(aWine({ color: 'rosé' }), { colors: ['red'] })).toBe(false)
    expect(passesFilters(aWine(), { colors: ['red'] })).toBe(false)
  })

  test('beverage type filter', () => {
    expect(passesFilters(aWine({ beverageType: 'spirit' }), { beverageTypes: ['spirit'] })).toBe(
      true,
    )
    expect(passesFilters(aWine(), { beverageTypes: ['beer'] })).toBe(false)
  })

  test('favorite filter needs an explicit favorite tasting', () => {
    const favorite = aWine({ consumption: { userId: 'user-1', beverageId: 'w1', favorite: true } })
    expect(passesFilters(favorite, { favorite: true })).toBe(true)
    expect(passesFilters(aWine(), { favorite: true })).toBe(false)
  })

  test('status filter on cellar presence and consumption', () => {
    const inCellar = aWine({ cellar: { userId: 'user-1', beverageId: 'w1', row: 0, col: 0 } })
    const consumed = aWine({
      consumption: { userId: 'user-1', beverageId: 'w1', consumedDate: new Date() },
    })
    expect(passesFilters(inCellar, { status: 'in-cellar' })).toBe(true)
    expect(passesFilters(consumed, { status: 'in-cellar' })).toBe(false)
    expect(passesFilters(consumed, { status: 'consumed' })).toBe(true)
    expect(passesFilters(inCellar, { status: 'consumed' })).toBe(false)
    expect(passesFilters(aWine(), { status: 'all' })).toBe(true)
  })

  test('gifted filter accepts received or given wines', () => {
    const received = aWine({
      gift: { userId: 'user-1', beverageId: 'w1', received: { from: 'Alice' } },
    })
    const given = aWine({
      gift: { userId: 'user-1', beverageId: 'w1', given: { date: new Date() } },
    })
    expect(passesFilters(received, { gifted: true })).toBe(true)
    expect(passesFilters(given, { gifted: true })).toBe(true)
    expect(passesFilters(aWine(), { gifted: true })).toBe(false)
  })
})

describe('hasActiveFilters', () => {
  test('empty or neutral filters are inactive', () => {
    expect(hasActiveFilters({})).toBe(false)
    expect(hasActiveFilters({ colors: [], beverageTypes: [], status: 'all' })).toBe(false)
    expect(hasActiveFilters({ favorite: false, gifted: false })).toBe(false)
  })

  test('each facet activates the filters', () => {
    expect(hasActiveFilters({ colors: ['red'] })).toBe(true)
    expect(hasActiveFilters({ beverageTypes: ['wine'] })).toBe(true)
    expect(hasActiveFilters({ favorite: true })).toBe(true)
    expect(hasActiveFilters({ status: 'in-cellar' })).toBe(true)
    expect(hasActiveFilters({ status: 'consumed' })).toBe(true)
    expect(hasActiveFilters({ gifted: true })).toBe(true)
  })
})

describe('rankedHits', () => {
  const margaux = aWine({ id: 'w1', name: 'Margaux' })
  const chateauMargaux = aWine({ id: 'w2', name: 'Château Margaux' })
  const margauxPrefix = aWine({ id: 'w3', name: 'Margaux du Sud' })

  test('empty query with no filter searches nothing', () => {
    expect(rankedHits([margaux], '', {})).toEqual([])
    expect(rankedHits([margaux], '   ', {})).toEqual([])
  })

  test('empty query with filters browses by name, without matched fields', () => {
    const red = aWine({ id: 'w1', name: 'Zinfandel', color: 'red' })
    const otherRed = aWine({ id: 'w2', name: 'Beaujolais', color: 'red' })
    const white = aWine({ id: 'w3', name: 'Chablis', color: 'white' })
    const hits = rankedHits([red, white, otherRed], '', { colors: ['red'] })
    expect(hits.map((hit) => String(hit.item.name))).toEqual(['Beaujolais', 'Zinfandel'])
    expect(hits.every((hit) => hit.matchedFields.length === 0)).toBe(true)
  })

  test('ranks exact before prefix before substring, ties broken by name', () => {
    const hits = rankedHits([chateauMargaux, margauxPrefix, margaux], 'Margaux', {})
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w1', 'w3', 'w2'])
  })

  test('drops wines that do not match the query', () => {
    const petrus = aWine({ id: 'w4', name: 'Pétrus' })
    const hits = rankedHits([margaux, petrus], 'margaux', {})
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w1'])
  })

  test('combines text query with facet filters', () => {
    const redMargaux = aWine({ id: 'w1', name: 'Margaux', color: 'red' })
    const whiteMargaux = aWine({ id: 'w2', name: 'Margaux Blanc', color: 'white' })
    const hits = rankedHits([redMargaux, whiteMargaux], 'margaux', { colors: ['red'] })
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w1'])
  })

  test('an exact title outranks a wine that merely holds the same words', () => {
    const exact = aWine({ id: 'w1', name: 'Château Margaux' })
    const longer = aWine({ id: 'w2', name: 'Château Margaux Pavillon Rouge' })
    const hits = rankedHits([longer, exact], 'chateau margaux', {})
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w1', 'w2'])
    // 300 for the two words, plus 300 for the name matching the whole query.
    expect(hits[0]?.score).toBe(600)
  })

  test('accent-insensitive end to end', () => {
    const hits = rankedHits([chateauMargaux], 'chateau', {})
    expect(hits).toHaveLength(1)
    expect(hits[0]?.matchedFields).toEqual(['name'])
  })
})
