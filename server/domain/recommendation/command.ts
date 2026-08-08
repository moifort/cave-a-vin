import type { WriteBatch } from 'firebase-admin/firestore'
import type { BeverageId } from '~/domain/beverage/types'
import * as repository from '~/domain/recommendation/infrastructure/repository'
import type { Recommendation } from '~/domain/recommendation/types'
import type { UserId } from '~/domain/shared/types'
import { bulkSave } from '~/utils/firestore'

export namespace RecommendationCommand {
  export const create = async (rec: Recommendation, batch?: WriteBatch) =>
    repository.save(rec, batch)

  export const removeBeverage = async (
    userId: UserId,
    beverageId: BeverageId,
    batch?: WriteBatch,
  ) => {
    await repository.remove(userId, beverageId, batch)
  }

  // Erase the user's recommendations — an account deletion wipes them outright.
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }

  // Wipe the user's recommendations and restore the given records (account import).
  export const replaceAllForUser = async (userId: UserId, recommendations: Recommendation[]) => {
    await deleteAllForUser(userId)
    await bulkSave(recommendations, repository.save)
  }
}
