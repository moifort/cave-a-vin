import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { wineDetails } from '~/domain/beverage/business-rules'
import type {
  Beverage,
  BeverageId,
  BeverageName,
  GrapeVariety,
  WineColor,
} from '~/domain/beverage/types'
import type { Percentage, Region, UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BeverageCommand } = await import('~/domain/beverage/command')

const userId = 'user-1' as UserId
const name = (value: string) => value as BeverageName

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('BeverageCommand.add', () => {
  test('saves a wine with its color under the wine details', async () => {
    const result = await BeverageCommand.add(userId, name('Margaux'), 'wine', {
      wine: { color: 'red' as WineColor },
    })

    expect(result).not.toBe('color-required')
    const wine = result as Beverage
    expect(wine.beverageType).toBe('wine')
    expect(wineDetails(wine)?.color).toBe('red')
    expect(fake.snapshot('beverages').get(wine.id as string)?.beverageType).toBe('wine')
  })

  test('rejects a wine without color and writes nothing', async () => {
    const result = await BeverageCommand.add(userId, name('Margaux'), 'wine', {})

    expect(result).toBe('color-required')
    expect(fake.snapshot('beverages').size).toBe(0)
    expect(fake.directWrites).toEqual([])
  })

  test('saves a spirit without color', async () => {
    const result = await BeverageCommand.add(userId, name('Lagavulin 16'), 'spirit', {
      subtype: 'whisky',
      alcoholContent: 43 as Percentage,
    })

    expect(result).not.toBe('color-required')
    const spirit = result as Beverage
    expect(spirit.beverageType).toBe('spirit')
    expect(wineDetails(spirit)).toBeUndefined()
    expect(spirit.subtype).toBe('whisky')
    expect(spirit.alcoholContent).toBe(43 as Percentage)
  })

  test('rejects a subtype foreign to the beverage type and writes nothing', async () => {
    const result = await BeverageCommand.add(userId, name('Lagavulin 16'), 'spirit', {
      subtype: 'ipa',
    })

    expect(result).toBe('subtype-invalid')
    expect(fake.snapshot('beverages').size).toBe(0)
  })

  test('saves a wine with a wine subtype', async () => {
    const result = await BeverageCommand.add(userId, name('Taylor’s Tawny'), 'wine', {
      wine: { color: 'red' as WineColor },
      subtype: 'porto',
    })

    expect(result).not.toBe('subtype-invalid')
    expect((result as Beverage).subtype).toBe('porto')
  })
})

describe('BeverageCommand.update', () => {
  const seedBeer = (): Beverage => {
    const beer: Beverage = {
      id: 'b06cd9e2-8a7f-4a05-9b0e-111111111111' as BeverageId,
      userId,
      name: name('Chouffe'),
      beverageType: 'beer',
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    }
    fake.seed('beverages', beer.id as string, beer)
    return beer
  }

  const seedWine = (): Beverage => {
    const wine = {
      id: 'b06cd9e2-8a7f-4a05-9b0e-222222222222' as BeverageId,
      userId,
      name: name('Margaux'),
      beverageType: 'wine',
      producer: 'Château Margaux',
      region: 'Bordeaux',
      notes: 'À boire sur un gibier',
      alcoholContent: 13.5 as Percentage,
      purchase: { price: 350, date: new Date('2026-01-05') },
      place: { latitude: 44.8, longitude: -0.5, name: 'Pauillac' },
      wine: {
        color: 'red' as WineColor,
        vintage: 2015,
        appellation: 'Margaux',
        drinkWindow: { from: 2025, until: 2045 },
      },
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    } as unknown as Beverage
    fake.seed('beverages', wine.id as string, wine)
    return wine
  }

  describe('erasing fields', () => {
    test('empties a plain field the caller asked to clear', async () => {
      const wine = seedWine()

      await BeverageCommand.update(userId, wine.id, {}, ['notes', 'producer'])

      const saved = fake.snapshot('beverages').get(wine.id as string)
      expect(saved).not.toHaveProperty('notes')
      expect(saved).not.toHaveProperty('producer')
      expect(saved?.region).toBe('Bordeaux')
    })

    test('empties a nested field and keeps its siblings', async () => {
      const wine = seedWine()

      await BeverageCommand.update(userId, wine.id, {}, ['purchasePrice', 'appellation'])

      const saved = fake.snapshot('beverages').get(wine.id as string)
      expect(saved?.purchase).toEqual({ date: new Date('2026-01-05') })
      expect(saved?.wine).not.toHaveProperty('appellation')
      expect((saved?.wine as { vintage?: number } | undefined)?.vintage).toBe(2015)
    })

    test('drops a container left empty by the erasure', async () => {
      const wine = seedWine()

      await BeverageCommand.update(userId, wine.id, {}, [
        'latitude',
        'longitude',
        'placeName',
        'drinkFrom',
        'drinkUntil',
      ])

      const saved = fake.snapshot('beverages').get(wine.id as string)
      expect(saved).not.toHaveProperty('place')
      expect(saved?.wine).not.toHaveProperty('drinkWindow')
    })

    test('erases what is asked without touching what is written in the same call', async () => {
      const wine = seedWine()

      await BeverageCommand.update(userId, wine.id, { region: 'Médoc' as Region }, ['notes'])

      const saved = fake.snapshot('beverages').get(wine.id as string)
      expect(saved?.region).toBe('Médoc')
      expect(saved).not.toHaveProperty('notes')
    })

    test('refuses to erase the colour of a wine and writes nothing', async () => {
      const wine = seedWine()

      const result = await BeverageCommand.update(userId, wine.id, {}, ['color'])

      expect(result).toBe('color-required')
      const saved = fake.snapshot('beverages').get(wine.id as string)
      expect((saved?.wine as { color?: WineColor } | undefined)?.color).toBe('red')
    })
  })

  test('rejects switching to wine without providing a color', async () => {
    const beer = seedBeer()

    const result = await BeverageCommand.update(userId, beer.id, { beverageType: 'wine' })

    expect(result).toBe('color-required')
    expect(fake.snapshot('beverages').get(beer.id as string)?.beverageType).toBe('beer')
  })

  test('switches to wine when a color is provided', async () => {
    const beer = seedBeer()

    const result = await BeverageCommand.update(userId, beer.id, {
      beverageType: 'wine',
      wine: { color: 'white' as WineColor },
    })

    expect(result).not.toBe('color-required')
    expect(fake.snapshot('beverages').get(beer.id as string)?.beverageType).toBe('wine')
  })

  test('updates a beverage without color when its type does not require one', async () => {
    const beer = seedBeer()

    const result = await BeverageCommand.update(userId, beer.id, { subtype: 'blonde' })

    expect(result).not.toBe('color-required')
    expect(fake.snapshot('beverages').get(beer.id as string)?.subtype).toBe('blonde')
  })

  test('rejects an explicit subtype foreign to the (new) beverage type', async () => {
    const beer = seedBeer()

    const result = await BeverageCommand.update(userId, beer.id, { subtype: 'junmai' })

    expect(result).toBe('subtype-invalid')
    expect(fake.snapshot('beverages').get(beer.id as string)?.subtype).toBeUndefined()
  })

  test('drops the wine details when a wine becomes a beer', async () => {
    const wine: Beverage = {
      id: 'b06cd9e2-8a7f-4a05-9b0e-222222222222' as BeverageId,
      userId,
      name: name('Margaux'),
      beverageType: 'wine',
      wine: { color: 'red' as WineColor, grapeVarieties: ['Merlot' as GrapeVariety] },
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    }
    fake.seed('beverages', wine.id as string, wine)

    const result = await BeverageCommand.update(userId, wine.id, { beverageType: 'beer' })

    expect(result).not.toBe('color-required')
    const saved = fake.snapshot('beverages').get(wine.id as string)
    expect(saved?.wine).toBeUndefined()
    expect(saved?.beverageType).toBe('beer')
  })

  test('drops an inherited subtype that no longer fits the new type', async () => {
    const beer = seedBeer()
    fake.seed('beverages', beer.id as string, { ...beer, subtype: 'ipa' })

    const result = await BeverageCommand.update(userId, beer.id, {
      beverageType: 'wine',
      wine: { color: 'white' as WineColor },
    })

    expect(result).not.toBe('subtype-invalid')
    const saved = fake.snapshot('beverages').get(beer.id as string)
    expect(saved?.subtype).toBeUndefined()
    expect((saved?.wine as { color?: WineColor } | undefined)?.color).toBe('white')
  })

  test('keeps an inherited subtype still valid for the new type', async () => {
    const wine: Beverage = {
      id: 'b06cd9e2-8a7f-4a05-9b0e-333333333333' as BeverageId,
      userId,
      name: name('Crémant'),
      beverageType: 'wine',
      wine: { color: 'white' as WineColor },
      subtype: 'sparkling',
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    }
    fake.seed('beverages', wine.id as string, wine)

    const result = await BeverageCommand.update(userId, wine.id, { beverageType: 'sake' })

    expect(result).not.toBe('subtype-invalid')
    const saved = fake.snapshot('beverages').get(wine.id as string)
    expect(saved?.beverageType).toBe('sake')
    expect(saved?.subtype).toBe('sparkling')
  })
})
