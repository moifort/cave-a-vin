import { keyBy, range } from 'lodash-es'
import { BeverageQuery } from '~/domain/beverage/query'
import type { BeverageId } from '~/domain/beverage/types'
import { cellarGrid } from '~/domain/cellar/command'
import * as repository from '~/domain/cellar/infrastructure/repository'
import { CellarCol, CellarRow } from '~/domain/cellar/primitives'
import type {
  CellarBottle,
  CellarBottleOwner,
  CellarBottleView,
  OwnedBeverage,
} from '~/domain/cellar/types'
import { HouseholdQuery } from '~/domain/household/query'
import type { CellarScope } from '~/domain/household/types'
import type { UserId } from '~/domain/shared/types'

// A placed bottle projected with its grid labels — the shared cellar view shape,
// used by the queries below and by the placement mutations.
export const bottleView = (bottle: CellarBottle): CellarBottleView => ({
  ...bottle,
  rowLabel: CellarRow.toLabel(bottle.row),
  colLabel: CellarCol.toLabel(bottle.col),
})

// A bottle's owner as seen by the viewer: their own bottles carry no name (the UI
// omits the badge), a housemate's bottle carries theirs.
const ownerOf = (bottle: CellarBottle, viewerId: UserId, scope: CellarScope): CellarBottleOwner => {
  const isMine = bottle.userId === viewerId
  return {
    userId: bottle.userId,
    displayName: isMine ? undefined : scope.displayNames.get(bottle.userId),
    isMine,
  }
}

export namespace CellarQuery {
  // The configured grid dimensions for the caller's cellar scope, falling back to
  // the default size until onboarding sets them.
  export const config = async (
    userId: UserId,
  ): Promise<{ rows: number; cols: number; zones: number }> => cellarGrid(userId)

  export const info = async (userId: UserId) => {
    const [scope, { rows, cols, zones }] = await Promise.all([
      HouseholdQuery.cellarScope(userId),
      config(userId),
    ])
    return {
      rows,
      cols,
      zones,
      capacity: rows * cols,
      // Server-side aggregation over the whole household: never loads documents.
      placedCount: await repository.countByUsers(scope.memberIds),
    }
  }

  // Every bottle standing in the shared cellar, joined with its wine and tagged
  // with its owner — what the dashboard sums, sorts and dates. The wines are
  // loaded by id (one read per bottle), never through a library scan: a placed
  // bottle's wine always belongs to a household member, so the keyed batch holds.
  export const householdBottlesWithWine = async (userId: UserId) => {
    const [scope, bottles] = await Promise.all([
      HouseholdQuery.cellarScope(userId),
      householdPlacements(userId),
    ])
    const wines = await BeverageQuery.byBeverageIdsForUsers(
      scope.memberIds,
      bottles.map(({ beverageId }) => beverageId),
    )
    const beverageMap = keyBy(wines, 'id')
    return bottles.map((bottle) => {
      const wine = beverageMap[bottle.beverageId]
      if (!wine) {
        const at = `${bottle.row},${bottle.col}`
        throw new Error(`Beverage ${bottle.beverageId} not found for bottle at ${at}`)
      }
      return { ...bottle, wine, owner: ownerOf(bottle, userId, scope) }
    })
  }

  export const placements = async (userId: UserId) => {
    const bottles = await repository.findAllByUser(userId)
    return bottles.map(bottleView)
  }

  // Every placed bottle in the viewer's cellar scope — the household-wide
  // counterpart of placements(), degenerating to it (same memoized scan) when
  // solo. Widens the wine list and search so a shared-cellar bottle is visible
  // to every member, not only its owner.
  export const householdPlacements = async (userId: UserId) => {
    const scope = await HouseholdQuery.cellarScope(userId)
    return (await repository.findAllByUsers(scope.memberIds)).map(bottleView)
  }

  // Raw bottle records (no grid labels) — the read half of an account export.
  export const allRecords = async (userId: UserId) => repository.findAllByUser(userId)

  // One page of the shared grid in (row, col) order, each bottle joined with its
  // wine and tagged with its owner.
  export const bottlesPage = async (
    userId: UserId,
    { limit, after }: { limit: number; after?: BeverageId },
  ) => {
    const scope = await HouseholdQuery.cellarScope(userId)
    const { bottles, hasMore } = await repository.findBottlesPageForUsers(scope.memberIds, {
      limit,
      after,
    })
    const wines = await BeverageQuery.byBeverageIdsForUsers(
      scope.memberIds,
      bottles.map(({ beverageId }) => beverageId),
    )
    const beverageMap = keyBy(wines, 'id')
    const items = bottles
      .filter(({ beverageId }) => beverageMap[beverageId])
      .map((bottle) => ({
        ...bottleView(bottle),
        wine: beverageMap[bottle.beverageId],
        owner: ownerOf(bottle, userId, scope),
      }))
    return { items, hasMore }
  }

  // Cellar placements for a page of wines, each read at its owner's exact slot —
  // the shared-cellar loader. A bottle lives under `${owner}_${beverageId}`, so a
  // housemate's wine resolves its placement with no household scan and no waste.
  export const placementsByOwnedBeverages = async (wines: OwnedBeverage[]) =>
    (await repository.findManyByExactIds(wines)).map(bottleView)

  export const suggestPosition = async (userId: UserId) => {
    const [scope, { rows, cols }] = await Promise.all([
      HouseholdQuery.cellarScope(userId),
      config(userId),
    ])
    const allBottles = await repository.findAllByUsers(scope.memberIds)
    const result = suggest(allBottles, rows, cols)
    if (typeof result === 'string') return result
    return {
      row: result.row,
      col: result.col,
      rowLabel: CellarRow.toLabel(result.row),
      colLabel: CellarCol.toLabel(result.col),
    }
  }

  const suggest = (bottles: CellarBottle[], rows: number, cols: number) => {
    const occupied = bottles.map((bottle) => `${bottle.row},${bottle.col}`)
    const firstFree = range(rows)
      .flatMap((row) => range(cols).map((col) => ({ row, col })))
      .find(({ row, col }) => !occupied.includes(`${row},${col}`))
    if (!firstFree) return 'cellar-full' as const
    return { row: CellarRow(firstFree.row), col: CellarCol(firstFree.col) }
  }
}
