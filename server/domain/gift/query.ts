import type { BeverageId } from '~/domain/beverage/types'
import * as repository from '~/domain/gift/infrastructure/repository'
import type { UserId } from '~/domain/shared/types'

export namespace GiftQuery {
  export const all = async (userId: UserId) => repository.findAllByUser(userId)

  export const byBeverage = async (userId: UserId, beverageId: BeverageId) =>
    repository.findBy(userId, beverageId)

  // Gifts are sparse (a handful of records per user), so filtering the memoized
  // full scan beats a keyed getAll: one query costing #gifts reads for the whole
  // request, instead of one billed lookup per beverage on every page.
  export const byBeverageIds = async (userId: UserId, beverageIds: BeverageId[]) => {
    if (beverageIds.length === 0) return []
    const wanted = new Set(beverageIds)
    return (await repository.findAllByUser(userId)).filter((gift) => wanted.has(gift.beverageId))
  }
}
