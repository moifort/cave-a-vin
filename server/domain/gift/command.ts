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
