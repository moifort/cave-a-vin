import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SearchIndexUseCase } = await import('~/domain/search/use-case')

const userId = 'user-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const seedWine = () =>
  fake.seed('beverages', 'w1', {
    id: 'w1',
    userId,
    name: 'Château Margaux',
    beverageType: 'wine',
    region: 'Bordeaux',
    wine: { color: 'red', vintage: 2015 },
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })

const indexOf = (id: string) => (fake.snapshot('beverages').get(id)?.searchIndex ?? []) as string[]

describe('SearchIndexUseCase.refresh', () => {
  test('writes the wine own words and facets', async () => {
    seedWine()

    await SearchIndexUseCase.refresh(userId, 'w1' as BeverageId)

    expect(indexOf('w1')).toContain('margau')
    expect(indexOf('w1')).toContain('chateau')
    expect(indexOf('w1')).toContain('bordeau')
    expect(indexOf('w1')).toContain('color:red')
    expect(indexOf('w1')).toContain('2015')
  })

  test('picks up the satellites of the wine', async () => {
    seedWine()
    fake.seed('cellar', `${userId}_w1`, { userId, beverageId: 'w1', row: 0, col: 0 })
    fake.seed('tasting', `${userId}_w1`, { userId, beverageId: 'w1', favorite: true })

    await SearchIndexUseCase.refresh(userId, 'w1' as BeverageId)

    expect(indexOf('w1')).toContain('incellar')
    expect(indexOf('w1')).toContain(`fav:${userId}`)
  })

  test('a term that no longer applies disappears', async () => {
    seedWine()
    fake.seed('tasting', `${userId}_w1`, { userId, beverageId: 'w1', favorite: true })
    await SearchIndexUseCase.refresh(userId, 'w1' as BeverageId)
    expect(indexOf('w1')).toContain(`fav:${userId}`)

    fake.seed('tasting', `${userId}_w1`, { userId, beverageId: 'w1', favorite: false })
    await SearchIndexUseCase.refresh(userId, 'w1' as BeverageId)

    expect(indexOf('w1')).not.toContain(`fav:${userId}`)
  })

  test('a housemate favourite on a shared wine is indexed under their own name', async () => {
    seedWine()
    fake.seed('household-members', userId, {
      userId,
      householdId: 'h1',
      role: 'owner',
      joinedAt: new Date('2026-01-01'),
    })
    fake.seed('household-members', 'marie', {
      userId: 'marie',
      householdId: 'h1',
      role: 'member',
      joinedAt: new Date('2026-01-01'),
    })
    // Marie hearts a wine she does not own; the note lives under her own key.
    fake.seed('tasting', `marie_w1`, { userId: 'marie', beverageId: 'w1', favorite: true })

    await SearchIndexUseCase.refresh(userId, 'w1' as BeverageId)

    expect(indexOf('w1')).toContain('fav:marie')
    expect(indexOf('w1')).not.toContain(`fav:${userId}`)
  })

  test('a deleted wine is ignored rather than an error', async () => {
    expect(SearchIndexUseCase.refresh(userId, 'missing' as BeverageId)).resolves.toBeUndefined()
  })
})
