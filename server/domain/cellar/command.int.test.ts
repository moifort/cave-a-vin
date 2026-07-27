import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type {
  CellarBottle,
  CellarCol,
  CellarCols,
  CellarRow,
  CellarRows,
  CellarZones,
} from '~/domain/cellar/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { CellarCommand } = await import('~/domain/cellar/command')

const userId = 'user-1' as UserId
const row = (value: number) => value as CellarRow
const col = (value: number) => value as CellarCol
const wine = (id: string) => id as BeverageId

const bottle = (beverageId: string, r: number, c: number): CellarBottle => ({
  userId,
  beverageId: wine(beverageId),
  row: row(r),
  col: col(c),
  createdAt: new Date('2026-01-01'),
  updatedAt: new Date('2026-01-01'),
})

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('CellarCommand.moveBottle', () => {
  test('moves a bottle to a free position and journals the movement in a single batch', async () => {
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))

    const result = await CellarCommand.moveBottle(userId, wine('w1'), row(2), col(3))

    expect(result).not.toBe('not-in-cellar')
    const moved = result as CellarBottle
    expect(moved.row).toBe(row(2))
    expect(moved.col).toBe(col(3))

    // Atomicity contract: one batch, committed once, no writes outside it
    expect(fake.batches).toHaveLength(1)
    expect(fake.batches[0].commits).toBe(1)
    expect(fake.batches[0].ops).toHaveLength(3)
    expect(fake.directWrites).toEqual([])

    const cellarDoc = fake.snapshot('cellar').get(`${userId}_w1`)
    expect(cellarDoc?.row).toBe(2)
    expect(cellarDoc?.col).toBe(3)

    const journal = [...fake.snapshot('journal').values()]
    expect(journal).toHaveLength(2)
    const out = journal.find((entry) => entry.type === 'out')
    expect(out).toMatchObject({ beverageId: 'w1', row: 0, col: 0, userId })
    const entryIn = journal.find((entry) => entry.type === 'in')
    expect(entryIn).toMatchObject({ beverageId: 'w1', row: 2, col: 3, userId })
  })

  test('swaps with the occupant of the target position in one batch', async () => {
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))
    fake.seed('cellar', `${userId}_w2`, bottle('w2', 1, 1))

    const result = await CellarCommand.moveBottle(userId, wine('w1'), row(1), col(1))

    const moved = result as CellarBottle
    expect(moved.row).toBe(row(1))
    expect(moved.col).toBe(col(1))

    // 2 cellar saves + 4 journal entries, all in the same single-commit batch
    expect(fake.batches).toHaveLength(1)
    expect(fake.batches[0].commits).toBe(1)
    expect(fake.batches[0].ops).toHaveLength(6)
    expect(fake.directWrites).toEqual([])

    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toMatchObject({ row: 1, col: 1 })
    expect(fake.snapshot('cellar').get(`${userId}_w2`)).toMatchObject({ row: 0, col: 0 })

    const journal = [...fake.snapshot('journal').values()]
    const trail = journal.map(({ type, beverageId, row: r, col: c }) => ({
      type,
      beverageId,
      row: r,
      col: c,
    }))
    expect(trail).toContainEqual({ type: 'out', beverageId: 'w1', row: 0, col: 0 })
    expect(trail).toContainEqual({ type: 'in', beverageId: 'w1', row: 1, col: 1 })
    expect(trail).toContainEqual({ type: 'out', beverageId: 'w2', row: 1, col: 1 })
    expect(trail).toContainEqual({ type: 'in', beverageId: 'w2', row: 0, col: 0 })
    expect(trail).toHaveLength(4)
  })

  test('a failing commit leaves the cellar and journal untouched', async () => {
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))
    fake.seed('cellar', `${userId}_w2`, bottle('w2', 1, 1))
    fake.failCommitsWith(new Error('firestore unavailable'))

    await expect(CellarCommand.moveBottle(userId, wine('w1'), row(1), col(1))).rejects.toThrow(
      'firestore unavailable',
    )

    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toMatchObject({ row: 0, col: 0 })
    expect(fake.snapshot('cellar').get(`${userId}_w2`)).toMatchObject({ row: 1, col: 1 })
    expect(fake.snapshot('journal').size).toBe(0)
    expect(fake.directWrites).toEqual([])
  })

  test('returns not-in-cellar without writing anything', async () => {
    const result = await CellarCommand.moveBottle(userId, wine('w1'), row(1), col(1))

    expect(result).toBe('not-in-cellar')
    expect(fake.batches).toHaveLength(0)
    expect(fake.directWrites).toEqual([])
  })

  test('moving to the current position writes nothing', async () => {
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 2, 3))

    const result = await CellarCommand.moveBottle(userId, wine('w1'), row(2), col(3))

    expect((result as CellarBottle).beverageId).toBe(wine('w1'))
    expect(fake.batches).toHaveLength(0)
    expect(fake.directWrites).toEqual([])
    expect(fake.snapshot('journal').size).toBe(0)
  })
})

// The viewer 'user-1' shares a household with 'marie'.
const seedHousehold = () => {
  const memberDoc = (id: string, role: 'owner' | 'member') => ({
    userId: id,
    householdId: 'h1',
    displayName: id,
    role,
    joinedAt: new Date('2026-01-01'),
  })
  fake.seed('household-members', userId, memberDoc(userId, 'owner'))
  fake.seed('household-members', 'marie', memberDoc('marie', 'member'))
}

const marieBottle = (beverageId: string, r: number, c: number): CellarBottle => ({
  userId: user('marie'),
  beverageId: wine(beverageId),
  row: row(r),
  col: col(c),
  createdAt: new Date('2026-01-01'),
  updatedAt: new Date('2026-01-01'),
})

const user = (id: string) => id as UserId

// A beverage owned by the given user, minimal shape for the ownership guard.
const seedBeverage = (owner: string, id: string) =>
  fake.seed('beverages', id, {
    id: wine(id),
    userId: user(owner),
    name: `Wine ${id}`,
    beverageType: 'wine',
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  })

describe('CellarCommand.placeBeverage (household)', () => {
  test('rejects a slot occupied by a housemate’s bottle', async () => {
    seedHousehold()
    seedBeverage(userId, 'w1')
    fake.seed('cellar', 'marie_w2', marieBottle('w2', 0, 0))

    const result = await CellarCommand.placeBeverage(userId, wine('w1'), row(0), col(0))

    expect(result).toBe('position-occupied')
    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toBeUndefined()
  })

  test('places into a free slot next to a housemate’s bottle', async () => {
    seedHousehold()
    seedBeverage(userId, 'w1')
    fake.seed('cellar', 'marie_w2', marieBottle('w2', 0, 0))

    const result = await CellarCommand.placeBeverage(userId, wine('w1'), row(0), col(1))

    expect((result as CellarBottle).userId).toBe(userId)
    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toMatchObject({ row: 0, col: 1 })
  })

  test('refuses a slot past the last column of the grid, writing nothing', async () => {
    seedHousehold()
    seedBeverage(userId, 'w1')

    // The default grid is 6x8, so 0-based column 8 is one past its last slot.
    const result = await CellarCommand.placeBeverage(userId, wine('w1'), row(0), col(8))

    expect(result).toBe('out-of-grid')
    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toBeUndefined()
  })

  test('refuses to place a housemate’s beverage, writing nothing', async () => {
    seedHousehold()
    seedBeverage('marie', 'w2')

    const result = await CellarCommand.placeBeverage(userId, wine('w2'), row(3), col(3))

    expect(result).toBe('not-your-beverage')
    expect(fake.snapshot('cellar').get(`${userId}_w2`)).toBeUndefined()
    expect(fake.snapshot('cellar').get('marie_w2')).toBeUndefined()
  })
})

describe('CellarCommand.moveBottle (household)', () => {
  test('a member moves a housemate’s bottle, journaling under its owner', async () => {
    seedHousehold()
    fake.seed('cellar', 'marie_w2', marieBottle('w2', 0, 0))

    const result = await CellarCommand.moveBottle(userId, wine('w2'), row(3), col(4))

    expect((result as CellarBottle).userId).toBe(user('marie'))
    expect(fake.snapshot('cellar').get('marie_w2')).toMatchObject({ row: 3, col: 4 })
    // The movement lands in marie's journal, not the actor's.
    const journal = [...fake.snapshot('journal').values()]
    expect(journal.every((entry) => entry.userId === 'marie')).toBe(true)
    expect(journal).toHaveLength(2)
  })

  test('a cross-owner swap journals each bottle under its own owner', async () => {
    seedHousehold()
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))
    fake.seed('cellar', 'marie_w2', marieBottle('w2', 1, 1))

    await CellarCommand.moveBottle(userId, wine('w1'), row(1), col(1))

    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toMatchObject({ row: 1, col: 1, userId })
    expect(fake.snapshot('cellar').get('marie_w2')).toMatchObject({
      row: 0,
      col: 0,
      userId: 'marie',
    })
    const journal = [...fake.snapshot('journal').values()]
    const w1Entries = journal.filter((entry) => entry.beverageId === 'w1')
    const w2Entries = journal.filter((entry) => entry.beverageId === 'w2')
    expect(w1Entries.every((entry) => entry.userId === userId)).toBe(true)
    expect(w2Entries.every((entry) => entry.userId === 'marie')).toBe(true)
  })

  test('refuses a destination past the last row of the grid, leaving the bottle put', async () => {
    fake.seed('cellar-configs', `usr_${userId}`, { rows: 6, cols: 8, zones: 1 })
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))

    const result = await CellarCommand.moveBottle(userId, wine('w1'), row(6), col(0))

    expect(result).toBe('out-of-grid')
    expect(fake.snapshot('cellar').get(`${userId}_w1`)).toMatchObject({ row: 0, col: 0 })
    expect(fake.snapshot('journal').size).toBe(0)
  })
})

describe('CellarCommand.reconfigure', () => {
  const rows = (value: number) => value as CellarRows
  const cols = (value: number) => value as CellarCols
  const zones = (value: number) => value as CellarZones

  test('overwrites the config for a solo cellar (usr_ key)', async () => {
    fake.seed('cellar-configs', `usr_${userId}`, { rows: 6, cols: 8, zones: 1 })

    const result = await CellarCommand.reconfigure(userId, rows(10), cols(5), zones(2))

    expect(result).toEqual({ rows: rows(10), cols: cols(5), zones: zones(2) })
    expect(fake.snapshot('cellar-configs').get(`usr_${userId}`)).toEqual({
      rows: 10,
      cols: 5,
      zones: 2,
    })
  })

  test('shrinks when every placed bottle still fits the new grid', async () => {
    fake.seed('cellar-configs', `usr_${userId}`, { rows: 10, cols: 10, zones: 1 })
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 3, 4))

    const result = await CellarCommand.reconfigure(userId, rows(4), cols(5), zones(1))

    expect(result).toEqual({ rows: rows(4), cols: cols(5), zones: zones(1) })
    expect(fake.snapshot('cellar-configs').get(`usr_${userId}`)).toMatchObject({ rows: 4, cols: 5 })
  })

  test('refuses to shrink below a placed bottle and leaves the config untouched', async () => {
    fake.seed('cellar-configs', `usr_${userId}`, { rows: 10, cols: 10, zones: 1 })
    fake.seed('cellar', `${userId}_w1`, bottle('w1', 0, 0))
    fake.seed('cellar', `${userId}_w2`, bottle('w2', 8, 2)) // row out of a 4-row grid
    fake.seed('cellar', `${userId}_w3`, bottle('w3', 1, 7)) // col out of a 5-col grid

    const result = await CellarCommand.reconfigure(userId, rows(4), cols(5), zones(1))

    expect(result).toEqual({ outOfBounds: 2 })
    expect(fake.snapshot('cellar-configs').get(`usr_${userId}`)).toMatchObject({
      rows: 10,
      cols: 10,
    })
  })

  test("a housemate's out-of-bounds bottle blocks the resize on the shared (hh_) config", async () => {
    seedHousehold()
    fake.seed('cellar-configs', 'hh_h1', { rows: 10, cols: 10, zones: 1 })
    fake.seed('cellar', 'marie_w2', marieBottle('w2', 9, 1)) // row out of a 4-row grid

    const result = await CellarCommand.reconfigure(userId, rows(4), cols(5), zones(1))

    expect(result).toEqual({ outOfBounds: 1 })
    expect(fake.snapshot('cellar-configs').get('hh_h1')).toMatchObject({ rows: 10, cols: 10 })
  })
})
