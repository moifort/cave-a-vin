import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { HouseholdId, HouseholdMember } from '~/domain/household/types'
import type { PersonName, UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { DashboardQuery } = await import('~/domain/dashboard/query')
const { CellarCommand } = await import('~/domain/cellar/command')

const userId = 'user-1' as UserId
const currentYear = new Date().getFullYear()

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const seedDashboardData = () => {
  fake.seed('beverages', 'w1', {
    id: 'w1',
    userId,
    name: 'Château Cave',
    beverageType: 'wine',
    purchase: { price: 30 },
    wine: { color: 'red', drinkWindow: { from: currentYear - 1, until: currentYear + 5 } },
    createdAt: new Date('2026-01-10'),
  })
  fake.seed('beverages', 'w2', {
    id: 'w2',
    userId,
    name: 'Domaine Favori',
    beverageType: 'wine',
    wine: { color: 'white', vintage: 2019 },
    createdAt: new Date('2026-01-05'),
  })
  fake.seed('cellar', `${userId}_w1`, {
    userId,
    beverageId: 'w1',
    row: 0,
    col: 0,
    createdAt: new Date('2026-01-10'),
    updatedAt: new Date('2026-01-10'),
  })
  fake.seed('tasting', `${userId}_w2`, {
    userId,
    beverageId: 'w2',
    favorite: true,
    rating: 5,
    consumedDate: new Date('2026-02-01'),
  })
  fake.seed('journal', 'j1', {
    userId,
    beverageId: 'w1',
    type: 'in',
    row: 0,
    col: 0,
    date: new Date('2026-01-10'),
  })
  fake.seed('journal', 'j2', {
    userId,
    beverageId: 'w2',
    type: 'out',
    row: 1,
    col: 1,
    date: new Date('2026-02-01'),
  })
}

const member = (id: string, role: 'owner' | 'member'): HouseholdMember => ({
  userId: id as UserId,
  householdId: 'h1' as HouseholdId,
  displayName: `${id} name` as PersonName,
  role,
  joinedAt: new Date('2026-01-01'),
})

// A member who joined an existing cellar: they own nothing yet, everything on
// screen is the owner's. This is the shape the invited user sees on first launch.
const seedInvitedMember = () => {
  fake.seed('household-members', 'owner', member('owner', 'owner'))
  fake.seed('household-members', 'guest', member('guest', 'member'))
  fake.seed('beverages', 'o1', {
    id: 'o1',
    userId: 'owner',
    name: 'Château Partagé',
    beverageType: 'wine',
    purchase: { price: 42 },
    wine: { color: 'red', drinkWindow: { from: currentYear - 1, until: currentYear + 5 } },
    createdAt: new Date('2026-01-10'),
  })
  fake.seed('cellar', 'owner_o1', {
    userId: 'owner',
    beverageId: 'o1',
    row: 0,
    col: 0,
    createdAt: new Date('2026-01-10'),
    updatedAt: new Date('2026-01-10'),
  })
  fake.seed('journal', 'j-owner', {
    userId: 'owner',
    beverageId: 'o1',
    type: 'in',
    row: 0,
    col: 0,
    date: new Date('2026-01-10'),
  })
  fake.seed('tasting', 'owner_o1', {
    userId: 'owner',
    beverageId: 'o1',
    favorite: true,
    rating: 5,
    consumedDate: new Date('2026-02-01'),
  })
}

describe('DashboardQuery.view (household)', () => {
  test('an invited member sees the cellar they were shared', async () => {
    seedInvitedMember()

    const view = await DashboardQuery.view('guest' as UserId)

    expect(view.bottleCount).toBe(1)
    expect(view.totalValue).toBe(42)
    expect(view.readyToDrink).toMatchObject([{ id: 'o1', position: 'A1' }])
    expect(view.lastBottle).toMatchObject({ wine: { id: 'o1' }, position: 'A1' })
    expect(view.history).toHaveLength(1)
    expect(view.history[0]?.actor).toMatchObject({ displayName: 'owner name', isMine: false })
  })

  test('favorites stay personal: a housemate’s tasting note is not the viewer’s', async () => {
    seedInvitedMember()

    const view = await DashboardQuery.view('guest' as UserId)

    expect(view.favorites).toEqual([])
  })

  test('a member’s own favorite counts even on a bottle the household shares', async () => {
    seedInvitedMember()
    fake.seed('tasting', 'guest_o1', {
      userId: 'guest',
      beverageId: 'o1',
      favorite: true,
      rating: 4,
      consumedDate: new Date('2026-03-01'),
    })

    const view = await DashboardQuery.view('guest' as UserId)

    expect(view.favorites).toMatchObject([{ id: 'o1', name: 'Château Partagé', rating: 4 }])
  })
})

describe('DashboardQuery.view', () => {
  test('assembles the dashboard view', async () => {
    seedDashboardData()

    const view = await DashboardQuery.view(userId)

    expect(view.bottleCount).toBe(1)
    expect(view.capacity).toBe(48)
    expect(view.totalValue).toBe(30)
    expect(view.readyToDrink).toMatchObject([{ id: 'w1', position: 'A1', urgent: false }])
    expect(view.favorites).toMatchObject([{ id: 'w2', name: 'Domaine Favori', rating: 5 }])
    expect(view.lastBottle).toMatchObject({ wine: { id: 'w1' }, position: 'A1' })
    expect(view.lastExit).toMatchObject({ beverageId: 'w2', type: 'out' })
    expect(view.history).toHaveLength(2)
  })

  test('the total value counts the bottles in the cellar, not the whole library', async () => {
    seedDashboardData()
    // A priced wine that never made it to a slot: owned, listed, but not stock.
    fake.seed('beverages', 'w3', {
      id: 'w3',
      userId,
      name: 'Château Jamais Rangé',
      beverageType: 'wine',
      purchase: { price: 80 },
      wine: { color: 'red' },
      createdAt: new Date('2026-01-12'),
    })

    const view = await DashboardQuery.view(userId)

    expect(view.totalValue).toBe(30)
    expect(view.bottleCount).toBe(1)
  })

  test('taking a bottle out drops its price from the total value', async () => {
    seedDashboardData()

    await CellarCommand.removeBeverage(userId, 'w1' as BeverageId)
    const view = await DashboardQuery.view(userId)

    // The wine stays in the library, its price leaves the cellar with the bottle.
    expect(view.totalValue).toBe(0)
    expect(view.bottleCount).toBe(0)
  })

  test('every read is bounded: no library or journal scan', async () => {
    seedDashboardData()

    const before = { docReads: fake.docReads, queryReads: fake.queryReads }
    await DashboardQuery.view(userId)

    // The cellar scan, the journal page, the limit(1) latest exit and the
    // favorites query — never a scan of the beverages or the whole journal.
    expect(fake.queryReads - before.queryReads).toBe(4)
    // Keyed doc reads: the scope membership doc, the cellar-config doc, the
    // placed bottle's wine (w1), the page's wines (w1+w2), the exit's wine (w2)
    // and the favorite's wine (w2) — each batch bounded by its section cap.
    expect(fake.docReads - before.docReads).toBe(7)
  })

  test('the read budget stays flat as the journal and library grow', async () => {
    seedDashboardData()
    // A mature account: hundreds of wines and journal entries beyond the caps.
    for (let i = 0; i < 200; i++) {
      fake.seed('beverages', `extra-${i}`, {
        id: `extra-${i}`,
        userId,
        name: `Extra ${i}`,
        beverageType: 'wine',
        createdAt: new Date('2025-01-01'),
      })
      fake.seed('journal', `extra-j-${i}`, {
        userId,
        beverageId: 'w1',
        type: 'in',
        row: 0,
        col: 0,
        date: new Date('2025-01-01'),
      })
    }

    const before = { docReads: fake.docReads, queryReads: fake.queryReads }
    const view = await DashboardQuery.view(userId)

    expect(view.bottleCount).toBe(1)
    expect(view.lastExit).toMatchObject({ beverageId: 'w2', type: 'out' })
    // Identical to the small-account budget: growth costs nothing.
    expect(fake.queryReads - before.queryReads).toBe(4)
    expect(fake.docReads - before.docReads).toBe(7)
  })
})
