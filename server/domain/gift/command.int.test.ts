import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { PersonName, UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { GiftCommand } = await import('~/domain/gift/command')

const userId = 'user-1' as UserId
const beverageId = 'w1' as BeverageId
const person = (value: string) => value as PersonName

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('GiftCommand.correctGiven', () => {
  const seedGiven = (given: Record<string, unknown>) =>
    fake.seed('gift', `${userId}_w1`, { userId, beverageId, given })

  test('renames the recipient without moving the date', async () => {
    seedGiven({ recipientName: 'Jean', date: new Date('2026-02-20') })

    const result = await GiftCommand.correctGiven(userId, beverageId, {
      recipientName: person('Jeanne'),
    })

    expect(result).toBeUndefined()
    expect(fake.snapshot('gift').get(`${userId}_w1`)?.given).toEqual({
      recipientName: 'Jeanne',
      date: new Date('2026-02-20'),
    })
  })

  test('drops a recipient the caller no longer names', async () => {
    seedGiven({ recipientName: 'Jean', date: new Date('2026-02-20') })

    await GiftCommand.correctGiven(userId, beverageId, { date: new Date('2026-03-01') })

    expect(fake.snapshot('gift').get(`${userId}_w1`)?.given).toEqual({
      date: new Date('2026-03-01'),
    })
  })

  test('keeps the received-from provenance alongside', async () => {
    fake.seed('gift', `${userId}_w1`, {
      userId,
      beverageId,
      given: { date: new Date('2026-02-20') },
      received: { from: 'Marie' },
    })

    await GiftCommand.correctGiven(userId, beverageId, { recipientName: person('Paul') })

    expect(fake.snapshot('gift').get(`${userId}_w1`)?.received).toEqual({ from: 'Marie' })
  })

  // Correcting is not recording: a bottle still in the cellar has no gift to fix.
  test('refuses a bottle that was never given away', async () => {
    fake.seed('gift', `${userId}_w1`, { userId, beverageId, received: { from: 'Marie' } })

    const result = await GiftCommand.correctGiven(userId, beverageId, {
      recipientName: person('Paul'),
    })

    expect(result).toBe('not-found')
    expect(fake.snapshot('gift').get(`${userId}_w1`)?.given).toBeUndefined()
  })
})
