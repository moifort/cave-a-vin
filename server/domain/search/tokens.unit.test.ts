import { describe, expect, test } from 'bun:test'
import { canonical, queryTerms, searchIndexOf, wordTokens } from '~/domain/search/tokens'
import type { SearchableWine } from '~/domain/search/types'
import type { UserId } from '~/domain/shared/types'

const owner = 'user-1' as UserId

const aWine = (overrides: Record<string, unknown> = {}): SearchableWine =>
  ({
    id: 'w1',
    userId: owner,
    name: 'Château Margaux',
    beverageType: 'wine',
    wine: {},
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
    ...overrides,
  }) as SearchableWine

describe('canonical', () => {
  test('strips accents and lowercases', () => {
    expect(canonical('Château')).toBe('chateau')
  })

  test('drops a trailing plural mark beyond three letters', () => {
    expect(canonical('chateaux')).toBe('chateau')
    expect(canonical('vins')).toBe('vin')
  })

  test('keeps a short word whole', () => {
    expect(canonical('vin')).toBe('vin')
    expect(canonical('cos')).toBe('cos')
  })

  test('cuts an elision', () => {
    expect(canonical("d'yquem")).toBe('yquem')
  })
})

describe('wordTokens', () => {
  test('yields one canonical token per word, never a prefix', () => {
    expect(wordTokens('Château Margaux')).toEqual(['chateau', 'margau'])
  })

  test('splits on spaces and hyphens', () => {
    expect(wordTokens('vin-jaune')).toEqual(['vin', 'jaune'])
  })

  test('nothing from an absent text', () => {
    expect(wordTokens(undefined)).toEqual([])
  })
})

describe('searchIndexOf', () => {
  test('holds the canonical form of the wine words', () => {
    const tokens = searchIndexOf(aWine({ name: 'Margaux', region: 'Bordeaux' }))
    expect(tokens).toContain('margau')
    expect(tokens).toContain('bordeau')
    // Whole words only: a partially typed word finds nothing.
    expect(tokens).not.toContain('marg')
  })

  test('holds the vintage and its prefixes from two digits', () => {
    const tokens = searchIndexOf(aWine({ wine: { vintage: 2015 } }))
    expect(tokens).toContain('2015')
    expect(tokens).toContain('201')
    expect(tokens).toContain('20')
  })

  test('holds the intrinsic facets under their own namespace', () => {
    const tokens = searchIndexOf(aWine({ subtype: 'porto', wine: { color: 'red' } }))
    expect(tokens).toContain('color:red')
    expect(tokens).toContain('type:wine')
    expect(tokens).toContain('subtype:porto')
    // The subtype stays free-text searchable too.
    expect(tokens).toContain('porto')
  })

  test('marks a bottle placed in the cellar, without an owner prefix', () => {
    const tokens = searchIndexOf(
      aWine({ cellar: { userId: owner, beverageId: 'w1', row: 0, col: 0 } }),
    )
    expect(tokens).toContain('incellar')
  })

  test('prefixes the personal facets with their owner', () => {
    const tokens = searchIndexOf(
      aWine({
        consumption: { userId: owner, beverageId: 'w1', favorite: true },
        gift: { userId: owner, beverageId: 'w1', received: { from: 'Alice' } },
      }),
    )
    expect(tokens).toContain(`fav:${owner}`)
    expect(tokens).toContain(`gift:${owner}`)
    expect(tokens).toContain(`p:${owner}:alice`)
  })

  test('never repeats a token', () => {
    const tokens = searchIndexOf(aWine({ name: 'Margaux', producer: 'Margaux' }))
    expect(new Set(tokens).size).toBe(tokens.length)
  })
})

describe('queryTerms', () => {
  test('looks for the word in the wine text or among the viewer own people', () => {
    // Canonical on both sides: the stored token is 'margau' too.
    expect(queryTerms('margaux', owner)).toEqual(['margau', `p:${owner}:margau`])
  })

  test('canonicalizes the searched word like the stored one', () => {
    expect(queryTerms('Châteaux', owner)[0]).toBe('chateau')
  })
})
