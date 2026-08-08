import type { WriteBatch } from 'firebase-admin/firestore'
import type { BeverageId } from '~/domain/beverage/types'
import * as repository from '~/domain/gift/infrastructure/repository'
import type { Gift, GiftGiven } from '~/domain/gift/types'
import type { PersonName, UserId } from '~/domain/shared/types'
import { bulkSave } from '~/utils/firestore'

export namespace GiftCommand {
  // Record that the bottle was given away, preserving any received-from facet.
  export const giveTo = async (userId: UserId, beverageId: BeverageId, given: GiftGiven) => {
    const existing = await repository.findBy(userId, beverageId)
    return repository.save({ ...(existing ?? { userId, beverageId }), given })
  }

  // Correct the record of a bottle whose gifting already happened: it left the
  // cellar long ago, only what was written about it is wrong. An unnamed recipient
  // is erased rather than kept, since the caller edits the whole facet at once.
  //
  // Both facets are corrected in a single read-and-write: they share one document,
  // and two successive writes enlisted in the same batch would each be built on a
  // read that predates the other, so the last one would silently drop the first.
  export const correct = async (
    userId: UserId,
    beverageId: BeverageId,
    facets: { given?: { recipientName?: PersonName; date?: Date }; receivedFrom?: PersonName },
    batch?: WriteBatch,
  ) => {
    const existing = await repository.findBy(userId, beverageId)
    const alreadyGiven = existing?.given
    // Correcting is not recording: a bottle nobody gave away has no gift to fix.
    if (facets.given && !alreadyGiven) return 'not-found' as const

    const given: GiftGiven | undefined =
      facets.given && alreadyGiven
        ? {
            date: facets.given.date ?? alreadyGiven.date,
            ...(facets.given.recipientName ? { recipientName: facets.given.recipientName } : {}),
          }
        : alreadyGiven
    const received = facets.receivedFrom ? { from: facets.receivedFrom } : existing?.received

    await repository.save(
      { userId, beverageId, ...(given && { given }), ...(received && { received }) },
      batch,
    )
    return undefined
  }

  // Record who gave the bottle to us, preserving any given-away facet.
  export const receiveFrom = async (userId: UserId, beverageId: BeverageId, from: PersonName) => {
    const existing = await repository.findBy(userId, beverageId)
    return repository.save({ ...(existing ?? { userId, beverageId }), received: { from } })
  }

  export const removeBeverage = async (
    userId: UserId,
    beverageId: BeverageId,
    batch?: WriteBatch,
  ) => {
    await repository.remove(userId, beverageId, batch)
  }

  // Erase the user's gifts — an account deletion wipes them outright.
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }

  // Wipe the user's gifts and restore the given records (account import).
  export const replaceAllForUser = async (userId: UserId, gifts: Gift[]) => {
    await deleteAllForUser(userId)
    await bulkSave(gifts, repository.save)
  }
}
