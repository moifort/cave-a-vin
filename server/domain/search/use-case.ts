import { BeverageCommand } from '~/domain/beverage/command'
import { BeverageQuery } from '~/domain/beverage/query'
import type { BeverageId } from '~/domain/beverage/types'
import { CellarQuery } from '~/domain/cellar/query'
import { GiftQuery } from '~/domain/gift/query'
import { HouseholdQuery } from '~/domain/household/query'
import { RecommendationQuery } from '~/domain/recommendation/query'
import type { UserId } from '~/domain/shared/types'
import { TastingQuery } from '~/domain/tasting/query'
import { type IndexableWine, searchIndexOf } from './tokens'

export namespace SearchIndexUseCase {
  // Recompute what one wine can be found by, from its current state and that of
  // its satellites, and store it back on the wine. Every mutation that can change
  // an indexed term routes through here rather than editing the array itself:
  // one place to be right, and a term that no longer applies disappears because
  // the array is rebuilt whole, never patched.
  //
  // A wine the viewer cannot see, or that no longer exists, is a no-op: deletion
  // and reindexing race on purpose, the wine is gone and so is its index.
  export const refresh = async (viewerId: UserId, beverageId: BeverageId): Promise<void> => {
    const wine = await BeverageQuery.byIdForViewer(viewerId, beverageId)
    if (wine === 'not-found') return
    // Every member's notes are gathered, not just the owner's: a housemate can
    // heart or gift a bottle they do not own, and the array is rewritten whole,
    // so reading one person's records would erase everybody else's terms.
    const scope = await HouseholdQuery.cellarScope(wine.userId)
    const [cellar, ...perMember] = await Promise.all([
      CellarQuery.placementsByOwnedBeverages([{ id: beverageId, userId: wine.userId }]),
      ...scope.memberIds.map((memberId) =>
        Promise.all([
          TastingQuery.byBeverageIds(memberId, [beverageId]),
          GiftQuery.byBeverageIds(memberId, [beverageId]),
          RecommendationQuery.byBeverageIds(memberId, [beverageId]),
        ]),
      ),
    ])
    const indexable: IndexableWine = {
      ...wine,
      consumption: perMember.flatMap(([tastings]) => tastings),
      gift: perMember.flatMap(([, gifts]) => gifts),
      recommendation: perMember.flatMap(([, , recommendations]) => recommendations),
    }
    if (cellar[0]) indexable.cellar = cellar[0]
    await BeverageCommand.saveSearchIndex(beverageId, searchIndexOf(indexable))
  }
}
