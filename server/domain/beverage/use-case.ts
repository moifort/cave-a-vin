import { BeverageCommand } from '~/domain/beverage/command'
import type { BeverageId, BeverageName, BeverageType } from '~/domain/beverage/types'
import { CellarCommand } from '~/domain/cellar/command'
import { GiftCommand } from '~/domain/gift/command'
import { JournalCommand } from '~/domain/journal/command'
import { RecommendationCommand } from '~/domain/recommendation/command'
import type { PersonName, UserId } from '~/domain/shared/types'
import { TastingCommand } from '~/domain/tasting/command'
import { atomically } from '~/utils/firestore'

type BeverageData = Parameters<typeof BeverageCommand.add>[3]

export namespace BeverageUseCase {
  // Add a beverage and, when its provenance is known, record who gave it (the
  // giftedBy field lives in the gift domain — a beverage only carries what it is).
  export const add = async (
    userId: UserId,
    name: BeverageName,
    beverageType: BeverageType,
    data: BeverageData,
    receivedFrom?: PersonName,
  ) => {
    const result = await BeverageCommand.add(userId, name, beverageType, data)
    if (typeof result !== 'string' && receivedFrom)
      await GiftCommand.receiveFrom(userId, result.id, receivedFrom)
    return result
  }

  export const update = async (
    userId: UserId,
    id: BeverageId,
    data: Parameters<typeof BeverageCommand.update>[2],
    receivedFrom?: PersonName,
    erase: Parameters<typeof BeverageCommand.update>[3] = [],
  ) => {
    const result = await BeverageCommand.update(userId, id, data, erase)
    if (typeof result !== 'string' && receivedFrom)
      await GiftCommand.receiveFrom(userId, id, receivedFrom)
    return result
  }

  export const removeCompletely = async (userId: UserId, id: BeverageId) =>
    await atomically(async (batch) => {
      const error = await BeverageCommand.remove(userId, id, batch)
      if (error === 'not-found') return 'not-found' as const
      // Every domain enlists its deletions into the same batch: the beverage and
      // all related entries vanish together or not at all. CellarCommand
      // .eraseBeverage skips bottle-out journaling because the whole journal is
      // wiped here.
      await Promise.all([
        CellarCommand.eraseBeverage(userId, id, batch),
        TastingCommand.removeBeverage(userId, id, batch),
        GiftCommand.removeBeverage(userId, id, batch),
        RecommendationCommand.removeBeverage(userId, id, batch),
        JournalCommand.removeBeverage(userId, id, batch),
      ])
      return undefined
    })
}
