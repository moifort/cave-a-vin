import { BeverageCommand } from '~/domain/beverage/command'
import { BeverageQuery } from '~/domain/beverage/query'
import type { BeverageId } from '~/domain/beverage/types'
import { CellarQuery } from '~/domain/cellar/query'
import { GiftQuery } from '~/domain/gift/query'
import { RecommendationQuery } from '~/domain/recommendation/query'
import type { UserId } from '~/domain/shared/types'
import { TastingQuery } from '~/domain/tasting/query'
import { searchIndexOf } from './tokens'
import type { SearchableWine } from './types'

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
    // Satellites belong to the wine's owner: a housemate reindexing a shared
    // bottle must not stamp it with their own tasting note.
    const owner = wine.userId
    const [cellar, consumption, gift, recommendation] = await Promise.all([
      CellarQuery.placementsByOwnedBeverages([{ id: beverageId, userId: owner }]),
      TastingQuery.byBeverageIds(owner, [beverageId]),
      GiftQuery.byBeverageIds(owner, [beverageId]),
      RecommendationQuery.byBeverageIds(owner, [beverageId]),
    ])
    const searchable: SearchableWine = { ...wine }
    if (cellar[0]) searchable.cellar = cellar[0]
    if (consumption[0]) searchable.consumption = consumption[0]
    if (gift[0]) searchable.gift = gift[0]
    if (recommendation[0]) searchable.recommendation = recommendation[0]
    await BeverageCommand.saveSearchIndex(beverageId, searchIndexOf(searchable))
  }
}
