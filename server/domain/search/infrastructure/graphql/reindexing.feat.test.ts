import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { schema } = await import('~/domain/shared/graphql/schema')
const { beverageSatelliteLoaders } = await import('~/domain/shared/graphql/loaders')

const userId = 'user-1' as UserId
// BeverageId is a UUID scalar, so the seeded wine needs a real one.
const wineId = '11111111-1111-4111-8111-111111111111'

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

const execute = (source: string) =>
  graphql({
    schema,
    source,
    contextValue: { userId, event: undefined as never, loaders: beverageSatelliteLoaders(userId) },
  })

const seedWine = () =>
  fake.seed('beverages', wineId, {
    id: wineId,
    userId,
    name: 'Château Margaux',
    beverageType: 'wine',
    wine: { color: 'red' },
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })

const indexOf = (id: string) => (fake.snapshot('beverages').get(id)?.searchIndex ?? []) as string[]

// Every mutation that changes an indexed term must leave the wine findable by it.
// A missing call here is the failure mode this whole feature is exposed to: the
// wine keeps working everywhere except in the search, silently.
describe('mutations keep the search index in step', () => {
  test('adding a wine indexes it right away', async () => {
    const result = await execute(`
      mutation {
        addBeverage(input: { name: "Château Margaux", color: RED, region: "Bordeaux" }) {
          id
        }
      }
    `)
    expect(result.errors).toBeUndefined()
    const id = (result.data?.addBeverage as { id: string }).id

    expect(indexOf(id)).toContain('margau')
    expect(indexOf(id)).toContain('bordeau')
  })

  test('renaming a wine drops the former name', async () => {
    seedWine()
    await execute(`mutation { markFavorite(beverageId: "${wineId}", favorite: true) }`)
    expect(indexOf(wineId)).toContain('margau')

    const result = await execute(`
      mutation { updateBeverage(id: "${wineId}", input: { name: "Pétrus" }) { id } }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain('petru')
    expect(indexOf(wineId)).not.toContain('margau')
  })

  test('marking a favorite indexes it for that viewer only', async () => {
    seedWine()

    const result = await execute(`mutation { markFavorite(beverageId: "${wineId}", favorite: true) }`)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain(`fav:${userId}`)
  })

  test('unmarking a favorite removes the term', async () => {
    seedWine()
    await execute(`mutation { markFavorite(beverageId: "${wineId}", favorite: true) }`)

    await execute(`mutation { markFavorite(beverageId: "${wineId}", favorite: false) }`)

    expect(indexOf(wineId)).not.toContain(`fav:${userId}`)
  })

  test('recording a tasting indexes its guests', async () => {
    seedWine()

    const result = await execute(`
      mutation { recordTasting(beverageId: "${wineId}", input: { contacts: ["Alice Dupont"] }) }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain(`p:${userId}:alice`)
  })

  test('placing a bottle marks it as in the cellar', async () => {
    seedWine()

    const result = await execute(`
      mutation { placeBottle(beverageId: "${wineId}", row: 0, col: 0) { row col } }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain('incellar')
  })

  test('removing a bottle clears the cellar mark', async () => {
    seedWine()
    await execute(`mutation { placeBottle(beverageId: "${wineId}", row: 0, col: 0) { row col } }`)

    await execute(`mutation { removeBottle(beverageId: "${wineId}") }`)

    expect(indexOf(wineId)).not.toContain('incellar')
  })

  test('consuming a bottle indexes it as consumed', async () => {
    seedWine()
    await execute(`mutation { placeBottle(beverageId: "${wineId}", row: 0, col: 0) { row col } }`)

    const result = await execute(`
      mutation { consumeBottle(beverageId: "${wineId}", input: { consumedDate: "2026-02-01" }) }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain(`consumed:${userId}`)
    expect(indexOf(wineId)).not.toContain('incellar')
  })

  test('gifting a bottle indexes the recipient', async () => {
    seedWine()
    await execute(`mutation { placeBottle(beverageId: "${wineId}", row: 0, col: 0) { row col } }`)

    const result = await execute(`
      mutation {
        giftBottle(beverageId: "${wineId}", input: { giftedDate: "2026-02-01", recipientName: "Bob" })
      }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain(`gift:${userId}`)
    expect(indexOf(wineId)).toContain(`p:${userId}:bob`)
  })

  test('adding a recommendation indexes who made it', async () => {
    seedWine()

    const result = await execute(`
      mutation { addRecommendation(beverageId: "${wineId}", input: { recommenderName: "Carla" }) }
    `)

    expect(result.errors).toBeUndefined()
    expect(indexOf(wineId)).toContain(`p:${userId}:carla`)
  })
})
