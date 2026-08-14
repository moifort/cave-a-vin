import { describe, expect, test } from 'bun:test'
import { facetsOf, LONGEST_PHRASE } from '~/domain/search/vocabulary'

describe('facetsOf', () => {
  test('reads a wine subtype through the words of every served language', () => {
    for (const word of ['champagne', 'sparkling', 'Sekt', 'espumoso', 'spumante', 'シャンパン']) {
      expect(facetsOf(word)).toContain('subtype:sparkling')
    }
  })

  test('reads a robe and a beverage type', () => {
    expect(facetsOf('rouge')).toEqual(['color:red'])
    expect(facetsOf('birra')).toEqual(['type:beer'])
  })

  test('canonicalizes the way the index is written', () => {
    // "Champagnes" loses its plural mark exactly as the query does.
    expect(facetsOf('Champagnes')).toContain('subtype:sparkling')
    expect(facetsOf('CRÉMANT')).toContain('subtype:sparkling')
  })

  test('spans several words', () => {
    expect(facetsOf('vendanges tardives')).toEqual(['subtype:late-harvest'])
    expect(facetsOf('eau de vie')).toEqual(['subtype:eau-de-vie'])
  })

  test('gives every facet a word designates', () => {
    // "doux" is a sweet wine and a sweet cider: both are meant.
    expect(facetsOf('doux').toSorted()).toEqual(['subtype:doux', 'subtype:sweet'])
  })

  test('knows nothing of a word that designates no facet', () => {
    expect(facetsOf('margaux')).toEqual([])
    expect(facetsOf('')).toEqual([])
  })

  test('the longest entry spans three words', () => {
    expect(LONGEST_PHRASE).toBe(3)
  })
})
