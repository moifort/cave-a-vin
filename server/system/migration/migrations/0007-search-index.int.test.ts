import { beforeEach, describe, expect, test } from 'bun:test'
import { createFakeFirestore, type FakeFirestore } from '~/test/fake-firestore'
import { migration0007 } from './0007-search-index'

let fake: FakeFirestore

beforeEach(() => {
  fake = createFakeFirestore()
})

describe('migration 0007 search-index', () => {
  test('fills the index of every wine, satellites included', async () => {
    fake.seed('beverages', 'w1', {
      id: 'w1',
      userId: 'u1',
      name: 'Château Margaux',
      beverageType: 'wine',
      wine: { color: 'red', vintage: 2015 },
    })
    fake.seed('cellar', 'u1_w1', { userId: 'u1', beverageId: 'w1', row: 0, col: 0 })
    fake.seed('tasting', 'u1_w1', { userId: 'u1', beverageId: 'w1', favorite: true })

    const result = await migration0007.migrate({ db: fake.db })

    expect(result).toEqual({ ok: true, transformed: 1 })
    const index = fake.snapshot('beverages').get('w1')?.searchIndex as string[]
    expect(index).toContain('margau')
    expect(index).toContain('color:red')
    expect(index).toContain('incellar')
    expect(index).toContain('fav:u1')
  })

  test('a housemate note lands on the wine under their own name, not the owner one', async () => {
    fake.seed('beverages', 'w1', { id: 'w1', userId: 'u1', name: 'Margaux', beverageType: 'wine' })
    fake.seed('tasting', 'u2_w1', { userId: 'u2', beverageId: 'w1', favorite: true })

    await migration0007.migrate({ db: fake.db })

    const index = fake.snapshot('beverages').get('w1')?.searchIndex as string[]
    expect(index).toContain('fav:u2')
    expect(index).not.toContain('fav:u1')
  })

  test('is safe to run twice', async () => {
    fake.seed('beverages', 'w1', { id: 'w1', userId: 'u1', name: 'Margaux', beverageType: 'wine' })

    await migration0007.migrate({ db: fake.db })
    const first = fake.snapshot('beverages').get('w1')?.searchIndex
    await migration0007.migrate({ db: fake.db })

    expect(fake.snapshot('beverages').get('w1')?.searchIndex).toEqual(first)
  })
})
