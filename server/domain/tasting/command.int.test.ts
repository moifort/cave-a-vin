import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import type { Rating } from '~/domain/tasting/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { TastingCommand } = await import('~/domain/tasting/command')

const userId = 'user-1' as UserId
const beverageId = 'w1' as BeverageId
const rating = (value: number) => value as Rating

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('TastingCommand.create (merge-upsert)', () => {
  test('preserves an existing favorite when later recording a consumption', async () => {
    fake.seed('tasting', `${userId}_w1`, { userId, beverageId, favorite: true })

    await TastingCommand.create({
      userId,
      beverageId,
      rating: rating(4),
      tastingNotes: 'Belle robe',
    })

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.favorite).toBe(true)
    expect(saved?.rating).toBe(4)
    expect(saved?.tastingNotes).toBe('Belle robe')
  })

  test('preserves an existing rating and notes when only the favorite flag is provided', async () => {
    fake.seed('tasting', `${userId}_w1`, {
      userId,
      beverageId,
      rating: rating(4),
      tastingNotes: 'Épicé',
    })

    await TastingCommand.create({ userId, beverageId, favorite: true })

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.favorite).toBe(true)
    expect(saved?.rating).toBe(4)
    expect(saved?.tastingNotes).toBe('Épicé')
  })

  test('raises an existing rating without touching the rest of the note', async () => {
    fake.seed('tasting', `${userId}_w1`, {
      userId,
      beverageId,
      favorite: true,
      rating: rating(3),
      tastingNotes: 'Un peu fermé',
      consumedDate: new Date('2026-02-20'),
    })

    await TastingCommand.create({ userId, beverageId, rating: rating(5) })

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.rating).toBe(5)
    expect(saved?.favorite).toBe(true)
    expect(saved?.tastingNotes).toBe('Un peu fermé')
    expect(saved?.consumedDate).toEqual(new Date('2026-02-20'))
  })

  // How the app erases a comment: there is no "absent" value to send, so the empty
  // string is written as is and overwrites what was there.
  test('erases the comment when an empty one is recorded', async () => {
    fake.seed('tasting', `${userId}_w1`, {
      userId,
      beverageId,
      rating: rating(4),
      tastingNotes: 'À revoir',
    })

    await TastingCommand.create({ userId, beverageId, tastingNotes: '' })

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.tastingNotes).toBe('')
    expect(saved?.rating).toBe(4)
  })

  test('saves a fresh note when none exists', async () => {
    await TastingCommand.create({ userId, beverageId, rating: rating(5) })

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved).toEqual({ userId, beverageId, rating: 5 })
  })
})

describe('TastingCommand.setFavorite', () => {
  test('sets the flag while keeping the existing rating and notes', async () => {
    fake.seed('tasting', `${userId}_w1`, {
      userId,
      beverageId,
      rating: rating(3),
      tastingNotes: 'Vif',
    })

    await TastingCommand.setFavorite(userId, beverageId, true)

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.favorite).toBe(true)
    expect(saved?.rating).toBe(3)
    expect(saved?.tastingNotes).toBe('Vif')
  })

  test('creates a favorite-only note when none exists', async () => {
    await TastingCommand.setFavorite(userId, beverageId, true)

    expect(fake.snapshot('tasting').get(`${userId}_w1`)).toEqual({
      userId,
      beverageId,
      favorite: true,
    })
  })

  test('clears the flag without dropping the rest of the note', async () => {
    fake.seed('tasting', `${userId}_w1`, {
      userId,
      beverageId,
      favorite: true,
      rating: rating(5),
    })

    await TastingCommand.setFavorite(userId, beverageId, false)

    const saved = fake.snapshot('tasting').get(`${userId}_w1`)
    expect(saved?.favorite).toBe(false)
    expect(saved?.rating).toBe(5)
  })
})
