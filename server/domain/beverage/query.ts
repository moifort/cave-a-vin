import * as repository from '~/domain/beverage/infrastructure/repository'
import type {
  Beverage,
  BeverageId,
  BeverageListMode,
  BeverageSort,
  BeverageStatusFilter,
  BeverageSubtype,
  BeverageType,
  SortOrder,
  WineColor,
} from '~/domain/beverage/types'
import { CellarQuery } from '~/domain/cellar/query'
import { GiftQuery } from '~/domain/gift/query'
import { HouseholdQuery } from '~/domain/household/query'
import { RecommendationQuery } from '~/domain/recommendation/query'
import type { UserId } from '~/domain/shared/types'
import { TastingQuery } from '~/domain/tasting/query'
import { memoizedPerRequest } from '~/system/request-cache'

export type BeverageListCriteria = {
  mode: BeverageListMode
  status: BeverageStatusFilter
  sort: BeverageSort
  order: SortOrder
  limit: number
  after?: BeverageId
  color?: WineColor
  beverageType?: BeverageType
  subtype?: BeverageSubtype
}

// Cursor pagination is only safe when ordering by a field present on every
// beverage document: Firestore's orderBy silently DROPS documents missing the
// field, so paging by vintage/region/price would make beverages without them
// disappear (before pagination they showed up in the "Sans millésime/région" groups).
const CURSOR_SAFE_SORTS: readonly BeverageSort[] = ['createdAt', 'updatedAt']

export namespace BeverageQuery {
  export const findAll = async (userId: UserId) => repository.findAllByUser(userId)

  // The wines the viewer may see in their library and search: their own full
  // library, plus any household member's wine currently placed in the shared
  // cellar. A housemate's out-of-cellar wines (consumed, wishlist) stay private.
  // Memoized so the list, search and count paths share one merge per request.
  export const allVisibleTo = (userId: UserId): Promise<Beverage[]> =>
    memoizedPerRequest(`beverages:visible:${userId}`, async () => {
      const scope = await HouseholdQuery.cellarScope(userId)
      const own = await repository.findAllByUser(userId)
      if (scope.memberIds.length === 1) return own
      const housemates = scope.memberIds.filter((id) => id !== userId)
      const housemateSet = new Set(housemates)
      const placedByHousemates = (await CellarQuery.householdPlacements(userId))
        .filter((bottle) => housemateSet.has(bottle.userId))
        .map((bottle) => bottle.beverageId)
      const housemateWines = await repository.findManyByBeverageIdsForUsers(
        housemates,
        placedByHousemates,
      )
      return [...own, ...housemateWines]
    })

  // The owner's beverages carrying at least one of the given search terms. The
  // search domain decides what a term is, the beverage domain owns the lookup.
  export const bySearchTerms = async (ownerId: UserId, terms: string[]) =>
    repository.findBySearchTerms(ownerId, terms)

  export const byId = async (userId: UserId, id: BeverageId) => {
    const beverage = await repository.findBy(userId, id)
    if (!beverage) return 'not-found' as const
    return beverage
  }

  // A beverage the viewer is allowed to see: their own, or a household member's
  // (so a shared-cellar bottle opens its wine detail). Anything else is not-found.
  export const byIdForViewer = async (viewerId: UserId, id: BeverageId) => {
    const beverage = await repository.findById(id)
    if (!beverage) return 'not-found' as const
    if (beverage.userId === viewerId) return beverage
    const scope = await HouseholdQuery.cellarScope(viewerId)
    return scope.memberIds.includes(beverage.userId) ? beverage : ('not-found' as const)
  }

  // Batch-load a page of shared-cellar wines owned by any household member.
  export const byBeverageIdsForUsers = async (memberIds: UserId[], beverageIds: BeverageId[]) =>
    repository.findManyByBeverageIdsForUsers(memberIds, beverageIds)

  // A page of the beverage list, filtered and sorted per view.
  export const list = async (userId: UserId, criteria: BeverageListCriteria) => {
    const { mode, status, color, beverageType, subtype } = criteria
    const facetActive = color !== undefined || beverageType !== undefined || subtype !== undefined

    // The only truly paginated path: the unbounded default view, with no facet
    // active (facets live on the beverage document: a cursor would skip matches
    // page after page) and a sort field present on every document (see
    // CURSOR_SAFE_SORTS). Every other view is a bounded subset served in full,
    // so the client can sort and group it freely with no cross-page jumps.
    if (
      !facetActive &&
      mode === 'all' &&
      status === 'all' &&
      CURSOR_SAFE_SORTS.includes(criteria.sort)
    ) {
      const scope = await HouseholdQuery.cellarScope(userId)
      // Solo viewers keep Firestore-level pagination: a bounded limit+1 read.
      if (scope.memberIds.length === 1) {
        const { beverages, hasMore } = await repository.findPage(userId, criteria)
        return { items: beverages, hasMore, totalCount: beverages.length }
      }
      // Household viewers merge their library with housemates' in-cellar wines,
      // then sort and slice in memory: Firestore can't page across owners on a
      // shared sort with a stable cursor (its implicit __name__ tiebreak would
      // drop or repeat rows). The slice keeps the response and the satellite
      // loaders bounded to the page size.
      return paginateInMemory(await allVisibleTo(userId), criteria)
    }

    // Everything else (satellite views, facet filters, sorts on optional
    // fields): filter the visible set in memory — facets first, on fields the
    // beverages carry themselves (color lives in the wine details), then the
    // satellite-backed status — and serve the subset in full. The client sorts
    // and groups. Every collection touched here is a memoized full scan, so the
    // request never pays it twice. Satellite modes (favorites/gifted/recommended)
    // filter by the VIEWER's own satellites, so a housemate's cellar wine only
    // surfaces there once the viewer has favorited/received it themselves.
    const beverages = await allVisibleTo(userId)
    const candidates = await ofMode(userId, beverages, mode)
    const facetted = candidates.filter(
      (beverage) =>
        (!color || (beverage.beverageType === 'wine' && beverage.wine.color === color)) &&
        (!beverageType || beverage.beverageType === beverageType) &&
        (!subtype || beverage.subtype === subtype),
    )
    const items = await ofStatus(userId, facetted, status)
    return { items, hasMore: false, totalCount: items.length }
  }

  // Sort/slice a merged (multi-owner) set the way findPage pages a single owner.
  // Only CURSOR_SAFE_SORTS (createdAt/updatedAt, present on every document) reach
  // here; id breaks ties for a stable cursor. A missing `after` (its wine left
  // the cellar between pages) restarts from the top — parity with findPage.
  const paginateInMemory = (beverages: Beverage[], criteria: BeverageListCriteria) => {
    const { sort, order, limit, after } = criteria
    const time = (beverage: Beverage) =>
      (sort === 'updatedAt' ? beverage.updatedAt : beverage.createdAt).getTime()
    const sorted = [...beverages].sort((a, b) => {
      const delta = time(a) - time(b) || String(a.id).localeCompare(String(b.id))
      return order === 'desc' ? -delta : delta
    })
    const start = after ? sorted.findIndex((beverage) => beverage.id === after) + 1 : 0
    return {
      items: sorted.slice(start, start + limit),
      hasMore: start + limit < sorted.length,
      totalCount: sorted.length,
    }
  }

  const ofMode = async (userId: UserId, beverages: Beverage[], mode: BeverageListMode) => {
    if (mode === 'favorites') {
      const tastings = await TastingQuery.all(userId)
      const favorites = new Set(
        tastings
          .filter((tasting) => tasting.favorite === true)
          .map((tasting) => tasting.beverageId),
      )
      return beverages.filter((beverage) => favorites.has(beverage.id))
    }
    if (mode === 'recommended') {
      const recommendations = await RecommendationQuery.all(userId)
      const recommended = new Set(
        recommendations.map((recommendation) => recommendation.beverageId),
      )
      return beverages.filter((beverage) => recommended.has(beverage.id))
    }
    if (mode === 'gifted') {
      const gifts = await GiftQuery.all(userId)
      const received = new Set(
        gifts.filter((gift) => gift.received !== undefined).map((gift) => gift.beverageId),
      )
      return beverages.filter((beverage) => received.has(beverage.id))
    }
    return beverages
  }

  const ofStatus = async (userId: UserId, beverages: Beverage[], status: BeverageStatusFilter) => {
    if (status === 'in-cellar') {
      const placed = new Set(
        (await CellarQuery.householdPlacements(userId)).map((bottle) => bottle.beverageId),
      )
      return beverages.filter((beverage) => placed.has(beverage.id))
    }
    if (status === 'consumed') {
      const tastings = await TastingQuery.all(userId)
      const consumed = new Set(
        tastings
          .filter((tasting) => tasting.consumedDate != null)
          .map((tasting) => tasting.beverageId),
      )
      return beverages.filter((beverage) => consumed.has(beverage.id))
    }
    return beverages
  }
}
