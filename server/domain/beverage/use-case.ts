import { BeverageCommand } from '~/domain/beverage/command'
import type { BeverageId, BeverageName, BeverageType } from '~/domain/beverage/types'
import { CellarCommand } from '~/domain/cellar/command'
import { GiftCommand } from '~/domain/gift/command'
import { GiftQuery } from '~/domain/gift/query'
import { JournalCommand } from '~/domain/journal/command'
import { RecommendationCommand } from '~/domain/recommendation/command'
import type { Recommendation } from '~/domain/recommendation/types'
import type { PersonName, UserId } from '~/domain/shared/types'
import { TastingCommand } from '~/domain/tasting/command'
import type { TastingNote } from '~/domain/tasting/types'
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

  // One screen, one save. The wine sheet edits four records at once (the bottle,
  // its tasting note, the gift it was, the recommendation behind it); sending them
  // as four mutations meant four round trips and a half-written sheet whenever the
  // second one failed. Everything below lands together or not at all.
  //
  // Each part is optional: what the user did not touch is not sent, so a bottle
  // that was never tasted does not grow an empty tasting note just because its
  // name was corrected.
  export const saveSheet = async (
    userId: UserId,
    id: BeverageId,
    sheet: {
      beverage: Parameters<typeof BeverageCommand.update>[2]
      erase?: Parameters<typeof BeverageCommand.update>[3]
      receivedFrom?: PersonName
      tasting?: Omit<TastingNote, 'userId' | 'beverageId'>
      gift?: { recipientName?: PersonName; date?: Date }
      recommendation?: Omit<Recommendation, 'userId' | 'beverageId'>
    },
  ) => {
    // Every refusal is settled before the first write is enlisted: a batch commits
    // whatever it already holds, so a part refused halfway would leave the earlier
    // ones written — the very thing this exists to prevent. The beverage rules
    // (colour, subtype, existence) refuse before writing on their own; the gift
    // precondition is the one that has to be read up front.
    if (sheet.gift && !(await GiftQuery.byBeverage(userId, id))?.given)
      return 'gift-not-found' as const

    return await atomically(async (batch) => {
      const updated = await BeverageCommand.update(userId, id, sheet.beverage, sheet.erase, batch)
      if (typeof updated === 'string') return updated

      if (sheet.gift || sheet.receivedFrom)
        await GiftCommand.correct(
          userId,
          id,
          { given: sheet.gift, receivedFrom: sheet.receivedFrom },
          batch,
        )
      if (sheet.tasting)
        await TastingCommand.create({ userId, beverageId: id, ...sheet.tasting }, batch)
      if (sheet.recommendation)
        await RecommendationCommand.create(
          { userId, beverageId: id, ...sheet.recommendation },
          batch,
        )
      return updated
    })
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
