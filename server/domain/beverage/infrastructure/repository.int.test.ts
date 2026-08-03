import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const repository = await import('~/domain/beverage/infrastructure/repository')

const userId = 'user-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const seedWine = (id: string, searchIndex: string[], owner: string = userId) =>
  fake.seed('beverages', id, {
    id,
    userId: owner,
    name: 'Wine',
    beverageType: 'wine',
    searchIndex,
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })

describe('beverage search index', () => {
  test('saveSearchIndex replaces the tokens without touching the rest', async () => {
    seedWine('w1', ['old'])

    await repository.saveSearchIndex('w1' as BeverageId, ['margaux', 'marg'])

    const saved = fake.snapshot('beverages').get('w1')
    expect(saved?.searchIndex).toEqual(['margaux', 'marg'])
    expect(saved?.name).toBe('Wine')
  })

  test('findBySearchTerms returns only the owner wines holding one of the terms', async () => {
    seedWine('w1', ['margaux'])
    seedWine('w2', ['petrus'])
    seedWine('w3', ['margaux'], 'someone-else')

    const found = await repository.findBySearchTerms(userId, ['margaux', 'p:user-1:margaux'])

    expect(found.map((wine) => String(wine.id))).toEqual(['w1'])
  })

  test('no term means no query at all', async () => {
    seedWine('w1', ['margaux'])
    const before = fake.queryReads

    expect(await repository.findBySearchTerms(userId, [])).toEqual([])
    expect(fake.queryReads).toBe(before)
  })
})
