import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { schema } = await import('~/domain/shared/graphql/schema')
const { beverageSatelliteLoaders } = await import('~/domain/shared/graphql/loaders')

const userId = 'user-1' as UserId
const wineId = '00000000-0000-4000-8000-000000000001'

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('beverages', wineId, {
    id: wineId,
    userId,
    name: 'Margaux',
    beverageType: 'wine',
    producer: 'Château Margaux',
    region: 'Bordeaux',
    notes: 'À boire sur un gibier',
    purchase: { price: 350, date: new Date('2026-01-05') },
    wine: { color: 'red', vintage: 2015, appellation: 'Margaux' },
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })
})

const execute = (source: string) =>
  graphql({
    schema,
    source,
    contextValue: { userId, event: undefined as never, loaders: beverageSatelliteLoaders(userId) },
  })

const stored = () => fake.snapshot('beverages').get(wineId)

describe('updateBeverage', () => {
  test('erases the fields sent as an explicit null', async () => {
    const result = await execute(`
      mutation {
        updateBeverage(id: "${wineId}", input: { notes: null, purchasePrice: null }) { id }
      }
    `)

    expect(result.errors).toBeUndefined()
    expect(stored()).not.toHaveProperty('notes')
    expect(stored()?.purchase).toEqual({ date: new Date('2026-01-05') })
  })

  // The difference the erasure rests on: a field the client leaves out is a field
  // it says nothing about, and must survive the update untouched.
  test('leaves an omitted field alone', async () => {
    const result = await execute(`
      mutation {
        updateBeverage(id: "${wineId}", input: { region: "Médoc" }) { id }
      }
    `)

    expect(result.errors).toBeUndefined()
    expect(stored()?.region).toBe('Médoc')
    expect(stored()?.notes).toBe('À boire sur un gibier')
    expect(stored()?.producer).toBe('Château Margaux')
  })

  test('refuses to erase the colour of a wine', async () => {
    const result = await execute(`
      mutation {
        updateBeverage(id: "${wineId}", input: { color: null }) { id }
      }
    `)

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
    expect((stored()?.wine as { color?: string } | undefined)?.color).toBe('red')
  })
})
