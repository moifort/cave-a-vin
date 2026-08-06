import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { CellarCols, CellarRows, CellarZones } from '~/domain/cellar/types'
import type { HouseholdId, HouseholdMember, HouseholdRole } from '~/domain/household/types'
import type { PersonName, UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The account deletion deletes the Firebase Auth user through the identity module;
// the mock records the calls instead of hitting Firebase.
const deletedAuthUsers: string[] = []
mock.module('~/system/identity', () => ({
  deleteAuthUser: async (uid: string) => {
    deletedAuthUsers.push(uid)
  },
}))

const { UserUseCase } = await import('~/domain/user/use-case')
const { UserQuery } = await import('~/domain/user/query')
const { CellarQuery } = await import('~/domain/cellar/query')
const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')
const { FREE_MONTHLY_SCANS, WELCOME_SCANS } = await import('~/domain/quota/business-rules')

const user = (id: string) => id as UserId

const member = (
  id: string,
  householdId: string,
  role: HouseholdRole = 'owner',
  joinedAt = new Date('2026-01-01'),
): HouseholdMember => ({
  userId: user(id),
  householdId: householdId as HouseholdId,
  displayName: id as PersonName,
  role,
  joinedAt,
})

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  deletedAuthUsers.length = 0
})

describe('UserUseCase.completeOnboarding', () => {
  test('writes the profile and the cellar config together', async () => {
    await UserUseCase.completeOnboarding(user('u1'), {
      firstName: 'Thibaut' as PersonName,
      rows: 10 as CellarRows,
      cols: 5 as CellarCols,
      zones: 2 as CellarZones,
    })

    const me = await UserQuery.me(user('u1'))
    expect(me.firstName as string).toBe('Thibaut')
    expect(me.onboardingCompletedAt).toBeInstanceOf(Date)

    const config = await CellarQuery.config(user('u1'))
    expect(config).toMatchObject({ rows: 10, cols: 5, zones: 2 })
  })

  test('a solo user stores config under a usr_ scope key', async () => {
    await UserUseCase.completeOnboarding(user('solo'), {
      firstName: 'Marie' as PersonName,
      rows: 8 as CellarRows,
      cols: 6 as CellarCols,
      zones: 1 as CellarZones,
    })
    expect(fake.snapshot('cellar-configs').get('usr_solo')).toMatchObject({
      rows: 8,
      cols: 6,
      zones: 1,
    })
  })

  test('a household member stores config under the shared hh_ scope key', async () => {
    fake.seed('household-members', 'u1', member('u1', 'h1'))
    await UserUseCase.completeOnboarding(user('u1'), {
      firstName: 'Thibaut' as PersonName,
      rows: 12 as CellarRows,
      cols: 7 as CellarCols,
      zones: 2 as CellarZones,
    })
    expect(fake.snapshot('cellar-configs').get('hh_h1')).toMatchObject({
      rows: 12,
      cols: 7,
      zones: 2,
    })
  })

  test('never overwrites the shared grid a housemate already configured', async () => {
    fake.seed('household-members', 'a', member('a', 'h1'))
    fake.seed('household-members', 'b', member('b', 'h1'))
    fake.seed('cellar-configs', 'hh_h1', { rows: 12, cols: 7 })

    // Member B onboards later and picks a smaller size — the grid must not shrink.
    await UserUseCase.completeOnboarding(user('b'), {
      firstName: 'Marie' as PersonName,
      rows: 6 as CellarRows,
      cols: 5 as CellarCols,
      zones: 2 as CellarZones,
    })

    expect(fake.snapshot('cellar-configs').get('hh_h1')).toMatchObject({ rows: 12, cols: 7 })
    // B is still onboarded — only the profile was written, not the config.
    expect((await UserQuery.me(user('b'))).firstName as string).toBe('Marie')
  })

  test('every write lands in a single committed batch (atomic)', async () => {
    await UserUseCase.completeOnboarding(user('u1'), {
      firstName: 'Thibaut' as PersonName,
      rows: 10 as CellarRows,
      cols: 5 as CellarCols,
      zones: 1 as CellarZones,
    })
    expect(fake.batches).toHaveLength(1)
    expect(fake.batches[0].commits).toBe(1)
    // The cellar config, the granted scans, the profile.
    expect(fake.batches[0].ops).toHaveLength(3)
  })

  test('hands the new account the scans it needs to stock its cellar', async () => {
    await UserUseCase.completeOnboarding(user('u1'), {
      firstName: 'Thibaut' as PersonName,
      rows: 10 as CellarRows,
      cols: 5 as CellarCols,
      zones: 1 as CellarZones,
    })

    expect((await QuotaQuery.creditOf(user('u1'))).scans).toBe(WELCOME_SCANS)
  })

  test('never grants them twice, however often the wizard is run again', async () => {
    const onboard = () =>
      UserUseCase.completeOnboarding(user('u1'), {
        firstName: 'Thibaut' as PersonName,
        rows: 10 as CellarRows,
        cols: 5 as CellarCols,
        zones: 1 as CellarZones,
      })
    await onboard()
    // Draw the granted balance down, so a re-grant would show up as a balance
    // back at the full amount rather than where it was left.
    for (let i = 0; i <= FREE_MONTHLY_SCANS; i++) await QuotaCommand.record(user('u1'), 'free')

    await onboard()

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(WELCOME_SCANS - 1)
    // The second run rewrites the profile and nothing else: the grid it already
    // configured is left alone, and so is the balance.
    expect(fake.batches[1]?.ops).toHaveLength(1)
  })
})

describe('UserUseCase.deleteAccount', () => {
  // Seed one document the account owns in every per-user collection, plus a solo
  // cellar config, so the wipe has something to remove everywhere.
  const seedOwnedData = (id: string) => {
    fake.seed('beverages', `${id}_b`, { userId: user(id) })
    fake.seed('cellar', `${id}_b`, { userId: user(id) })
    fake.seed('tasting', `${id}_b`, { userId: user(id) })
    fake.seed('gift', `${id}_b`, { userId: user(id) })
    fake.seed('recommendation', `${id}_b`, { userId: user(id) })
    fake.seed('journal', `${id}_j`, { userId: user(id) })
    fake.seed('entitlements', id, { userId: user(id) })
    fake.seed('ai-quotas', `${id}_2026-07`, { userId: user(id) })
    fake.seed('ai-credits', id, { userId: user(id), scans: 20 })
    fake.seed('user-profiles', id, { userId: user(id), firstName: id })
    fake.seed('cellar-configs', `usr_${id}`, { rows: 8, cols: 6, zones: 1 })
  }

  const ownedCollections = [
    'beverages',
    'cellar',
    'tasting',
    'gift',
    'recommendation',
    'journal',
    'entitlements',
    'ai-quotas',
    'ai-credits',
    'user-profiles',
    'cellar-configs',
  ]

  test('wipes every collection the account owns and deletes the auth user', async () => {
    seedOwnedData('u1')
    // A second account whose identical data must survive untouched.
    seedOwnedData('u2')

    await UserUseCase.deleteAccount(user('u1'))

    for (const collection of ownedCollections) {
      const remaining = [...fake.snapshot(collection).values()]
      expect(remaining.every((doc) => (doc as { userId?: string }).userId !== 'u1')).toBe(true)
    }
    expect(fake.snapshot('cellar-configs').has('usr_u1')).toBe(false)
    expect((await UserQuery.me(user('u1'))).firstName).toBeUndefined()
    expect(deletedAuthUsers).toEqual(['u1'])

    // The other account is fully intact.
    expect(fake.snapshot('beverages').has('u2_b')).toBe(true)
    expect(fake.snapshot('cellar-configs').has('usr_u2')).toBe(true)
  })

  test('a solo account with no data still deletes cleanly (idempotent wipe)', async () => {
    await UserUseCase.deleteAccount(user('ghost'))
    expect(deletedAuthUsers).toEqual(['ghost'])
  })

  test('an owner leaving a shared household passes ownership and keeps the shared grid', async () => {
    fake.seed('households', 'h1', {
      id: 'h1',
      createdBy: user('u1'),
      createdAt: new Date('2026-01-01'),
    })
    fake.seed('household-members', 'u1', member('u1', 'h1', 'owner', new Date('2026-01-01')))
    fake.seed('household-members', 'u2', member('u2', 'h1', 'member', new Date('2026-02-01')))
    fake.seed('cellar-configs', 'hh_h1', { rows: 12, cols: 7, zones: 2 })
    seedOwnedData('u1')

    await UserUseCase.deleteAccount(user('u1'))

    // The leaver is gone, the remaining member inherits ownership.
    expect(fake.snapshot('household-members').has('u1')).toBe(false)
    expect(fake.snapshot('household-members').get('u2')).toMatchObject({ role: 'owner' })
    // The shared grid belongs to the remaining member — never deleted.
    expect(fake.snapshot('cellar-configs').get('hh_h1')).toMatchObject({ rows: 12 })
    // The leaver's own data is still wiped.
    expect(fake.snapshot('beverages').has('u1_b')).toBe(false)
    expect(deletedAuthUsers).toEqual(['u1'])
  })
})
