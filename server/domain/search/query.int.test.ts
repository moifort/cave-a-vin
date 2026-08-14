import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SearchQuery } = await import('~/domain/search/query')
const { migration0007 } = await import('~/system/migration/migrations/0007-search-index')

const userId = 'user-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const seed = () => {
  fake.seed('beverages', 'w1', {
    id: 'w1',
    userId,
    name: 'Château Margaux',
    beverageType: 'wine',
    producer: 'Château Margaux',
    region: 'Bordeaux',
    wine: { color: 'red', vintage: 2015 },
    createdAt: new Date('2026-01-03'),
    updatedAt: new Date('2026-01-03'),
  })
  fake.seed('beverages', 'w2', {
    id: 'w2',
    userId,
    name: 'Pouilly-Fumé',
    beverageType: 'wine',
    wine: { color: 'white', vintage: 2021 },
    createdAt: new Date('2026-01-02'),
    updatedAt: new Date('2026-01-02'),
  })
  fake.seed('beverages', 'w3', {
    id: 'w3',
    userId,
    name: 'Porto Vintage',
    beverageType: 'wine',
    subtype: 'porto',
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })
  fake.seed('cellar', `${userId}_w1`, {
    userId,
    beverageId: 'w1',
    row: 0,
    col: 0,
    createdAt: new Date('2026-01-03'),
    updatedAt: new Date('2026-01-03'),
  })
  fake.seed('tasting', `${userId}_w2`, {
    userId,
    beverageId: 'w2',
    favorite: true,
    consumedDate: new Date('2026-02-01'),
  })
  fake.seed('gift', `${userId}_w3`, {
    userId,
    beverageId: 'w3',
    received: { from: 'Alice Martin' },
    given: { date: new Date('2026-01-01'), recipientName: 'Bob Durand' },
  })
}

// A seeded database is not searchable until its wines carry their terms. Running
// the backfill migration is how production gets there, so the tests start from
// the same state instead of a hand-written index that could drift from it.
const seedAndIndex = async () => {
  seed()
  await migration0007.migrate({ db: fake.db })
}

const run = (query: string, filters = {}, limit = 50) =>
  SearchQuery.acrossCollections(userId, { query, filters, limit })

describe('SearchQuery.acrossCollections', () => {
  test('matches wine name and attaches satellites', async () => {
    await seedAndIndex()
    const { hits, totalCount } = await run('margaux')
    expect(totalCount).toBe(1)
    expect(String(hits[0]?.item.id)).toBe('w1')
    expect(hits[0]?.matchedFields).toContain('name')
    // Cellar satellite attached, so the GraphQL resolver skips the fallback.
    expect(hits[0]?.item.cellar).not.toBeNull()
  })

  test('matches a person across gift satellites', async () => {
    await seedAndIndex()
    const byGiver = await run('alice')
    expect(byGiver.hits.map((hit) => String(hit.item.id))).toEqual(['w3'])
    expect(byGiver.hits[0]?.matchedFields).toContain('gifted-by')

    const byRecipient = await run('bob')
    expect(byRecipient.hits.map((hit) => String(hit.item.id))).toEqual(['w3'])
    expect(byRecipient.hits[0]?.matchedFields).toContain('gift-recipient')
  })

  test('matches subtype and numeric vintage', async () => {
    await seedAndIndex()
    expect((await run('porto')).hits.map((hit) => String(hit.item.id))).toEqual(['w3'])
    expect((await run('2015')).hits.map((hit) => String(hit.item.id))).toEqual(['w1'])
  })

  test('a plural spelling finds the wine end to end', async () => {
    await seedAndIndex()
    // Firestore is asked for the canonical 'chateau', and the in-memory ranking
    // has to agree instead of dropping the wine over the extra letter.
    const { hits } = await run('chateaux')
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w1'])
  })

  test('ranks by relevance', async () => {
    fake.seed('beverages', 'a', {
      id: 'a',
      userId,
      name: 'Château Margaux',
      beverageType: 'wine',
      createdAt: new Date('2026-01-02'),
      updatedAt: new Date('2026-01-02'),
    })
    fake.seed('beverages', 'b', {
      id: 'b',
      userId,
      name: 'Margaux',
      beverageType: 'wine',
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    })
    await migration0007.migrate({ db: fake.db })

    const { hits } = await run('margaux')
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['b', 'a'])
  })

  test('filters browse the collection when the query is empty', async () => {
    await seedAndIndex()
    const { hits } = await run('', { colors: ['white'] })
    expect(hits.map((hit) => String(hit.item.id))).toEqual(['w2'])
    expect(hits[0]?.matchedFields).toEqual([])
  })

  test('empty query without filters returns nothing', async () => {
    await seedAndIndex()
    const { hits, totalCount } = await run('')
    expect(hits).toEqual([])
    expect(totalCount).toBe(0)
  })

  test('limit caps hits but totalCount stays full', async () => {
    await seedAndIndex()
    const { hits, totalCount } = await run('', { status: 'all', colors: ['red', 'white'] }, 1)
    expect(hits).toHaveLength(1)
    expect(totalCount).toBe(2)
  })

  test('finds a sparkling wine whose text carries no such word', async () => {
    fake.seed('beverages', 'w4', {
      id: 'w4',
      userId,
      name: 'Dom Pérignon',
      beverageType: 'wine',
      subtype: 'sparkling',
      wine: { color: 'white', vintage: 2012 },
      createdAt: new Date('2026-01-04'),
      updatedAt: new Date('2026-01-04'),
    })
    await seedAndIndex()

    for (const query of ['champagne', 'bulles', 'pétillant', 'sparkling']) {
      expect((await run(query)).hits.map((hit) => String(hit.item.id))).toEqual(['w4'])
    }
  })

  test('asks Firestore for the matching wines, never for the collection', async () => {
    await seedAndIndex()
    const before = { docReads: fake.docReads, queryReads: fake.queryReads }
    const { hits } = await run('margaux')

    expect(hits).toHaveLength(1)
    // Three queries: the indexed wine lookup, plus the gift and recommendation
    // scans those domains deliberately keep (sparse collections, see their
    // byBeverageIds). The beverages, cellar and tasting scans are gone.
    expect(fake.queryReads - before.queryReads).toBe(3)
  })

  test('the cost does not grow with the size of the collection', async () => {
    seed()
    for (let i = 0; i < 40; i++) {
      fake.seed('beverages', `filler-${i}`, {
        id: `filler-${i}`,
        userId,
        name: `Filler ${i}`,
        beverageType: 'wine',
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
      })
    }
    await migration0007.migrate({ db: fake.db })
    const before = fake.queryReads

    const { hits } = await run('margaux')

    expect(hits).toHaveLength(1)
    // Same three queries as on a three-bottle cellar: the forty extra wines are
    // never read, which is the whole point of the index.
    expect(fake.queryReads - before).toBe(3)
  })
})

describe('SearchQuery.acrossCollections — household visibility', () => {
  const householdMember = (id: string) => ({
    userId: id,
    householdId: 'h1',
    displayName: id,
    role: id === userId ? 'owner' : 'member',
    joinedAt: new Date('2026-01-01'),
  })

  // The viewer shares a household with 'marie'. Her m-in wine is in the shared
  // cellar; her m-out wine is not; she has a gift record naming a person.
  const seedHousehold = () => {
    fake.seed('household-members', userId, householdMember(userId))
    fake.seed('household-members', 'marie', householdMember('marie'))
    fake.seed('beverages', 'm-in', {
      id: 'm-in',
      userId: 'marie',
      name: 'Clos Marie',
      beverageType: 'wine',
      createdAt: new Date('2026-01-02'),
      updatedAt: new Date('2026-01-02'),
    })
    fake.seed('beverages', 'm-out', {
      id: 'm-out',
      userId: 'marie',
      name: 'Clos Cachet',
      beverageType: 'wine',
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    })
    fake.seed('cellar', 'marie_m-in', { userId: 'marie', beverageId: 'm-in', row: 0, col: 0 })
    fake.seed('gift', 'marie_m-in', {
      userId: 'marie',
      beverageId: 'm-in',
      received: { from: 'Sofia Rossi' },
    })
  }

  const seedHouseholdAndIndex = async () => {
    seedHousehold()
    await migration0007.migrate({ db: fake.db })
  }

  test('finds a housemate’s in-cellar wine but not their out-of-cellar one', async () => {
    await seedHouseholdAndIndex()
    expect((await run('clos')).hits.map((hit) => String(hit.item.id))).toEqual(['m-in'])
  })

  test('a housemate’s own gift/journal never produces a person match', async () => {
    seedHousehold()
    // 'Sofia' only appears in Marie's private gift record — off-limits to the viewer.
    expect((await run('sofia')).hits).toEqual([])
  })

  test('the favourites filter returns the viewer’s own, never a housemate’s', async () => {
    seedHousehold()
    // Marie hearts the bottle she shares with the viewer, who has not.
    fake.seed('tasting', 'marie_m-in', { userId: 'marie', beverageId: 'm-in', favorite: true })
    await migration0007.migrate({ db: fake.db })

    expect((await run('', { favorite: true })).hits).toEqual([])
  })
})
