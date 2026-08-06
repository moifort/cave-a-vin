import { beforeEach, describe, expect, test } from 'bun:test'
import { WELCOME_SCANS } from '~/domain/quota/business-rules'
import { createFakeFirestore, type FakeFirestore } from '~/test/fake-firestore'
import { migration0008 } from './0008-welcome-credits'

let fake: FakeFirestore

beforeEach(() => {
  fake = createFakeFirestore()
})

describe('migration 0008 welcome-credits', () => {
  test('grants the scans to every account that onboarded before they existed', async () => {
    fake.seed('user-profiles', 'u1', { userId: 'u1', firstName: 'Thibaut' })
    fake.seed('user-profiles', 'u2', { userId: 'u2', firstName: 'Marie' })

    const result = await migration0008.migrate({ db: fake.db })

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.snapshot('ai-credits').get('u1')).toEqual({ userId: 'u1', scans: WELCOME_SCANS })
    expect(fake.snapshot('ai-credits').get('u2')).toEqual({ userId: 'u2', scans: WELCOME_SCANS })
  })

  test('leaves a balance already spent where it is, rather than refilling it', async () => {
    fake.seed('user-profiles', 'u1', { userId: 'u1', firstName: 'Thibaut' })
    fake.seed('ai-credits', 'u1', { userId: 'u1', scans: 3 })

    const result = await migration0008.migrate({ db: fake.db })

    expect(result).toEqual({ ok: true, transformed: 0 })
    expect(fake.snapshot('ai-credits').get('u1')).toMatchObject({ scans: 3 })
  })

  test('is safe to run twice', async () => {
    fake.seed('user-profiles', 'u1', { userId: 'u1', firstName: 'Thibaut' })

    await migration0008.migrate({ db: fake.db })
    await migration0008.migrate({ db: fake.db })

    expect(fake.snapshot('ai-credits').get('u1')).toMatchObject({ scans: WELCOME_SCANS })
  })

  test('grants nothing to an account that never finished onboarding', async () => {
    const result = await migration0008.migrate({ db: fake.db })

    expect(result).toEqual({ ok: true, transformed: 0 })
    expect(fake.snapshot('ai-credits').size).toBe(0)
  })
})
