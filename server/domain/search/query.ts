import { BeverageQuery } from '~/domain/beverage/query'
import type { Beverage, BeverageId } from '~/domain/beverage/types'
import { CellarQuery } from '~/domain/cellar/query'
import { GiftQuery } from '~/domain/gift/query'
import { HouseholdQuery } from '~/domain/household/query'
import { RecommendationQuery } from '~/domain/recommendation/query'
import type { UserId } from '~/domain/shared/types'
import { TastingQuery } from '~/domain/tasting/query'
import { hasActiveFilters, narrowestSegment, querySegments, rankedHits } from './business-rules'
import { facetTerms, queryTerms } from './tokens'
import type { SearchableWine, SearchFilters } from './types'
import { facetsOf } from './vocabulary'

export namespace SearchQuery {
  // Search through the terms written on each wine: Firestore is asked for the
  // single most selective one, and everything else — the remaining words, the
  // facets, the housemate visibility rule, the ranking — is settled in memory on
  // the handful of documents that come back. One array clause per query is all
  // Firestore allows, so this split is imposed, not chosen.
  //
  // Wines span the household (a housemate's bottle is visible once it is placed
  // in the shared cellar), while tastings, gifts and recommendations stay the
  // viewer's own — a housemate's notes and journal never surface here.
  export const acrossCollections = async (
    userId: UserId,
    { query, filters, limit }: { query: string; filters: SearchFilters; limit: number },
  ) => {
    const tokens = querySegments(query)
    if (tokens.length === 0 && !hasActiveFilters(filters)) return { hits: [], totalCount: 0 }

    const scope = await HouseholdQuery.cellarScope(userId)
    // A segment is asked for as a word and as the facets it designates at once:
    // "champagne" has to bring back the bottle named Champagne Charlie and the
    // Dom Pérignon that carries the word nowhere. One disjunctive clause covers
    // both, which is all Firestore allows anyway.
    const segment = tokens.length > 0 ? narrowestSegment(tokens) : undefined
    const terms =
      segment === undefined
        ? facetTerms(filters, userId)
        : [...queryTerms(segment, userId), ...facetsOf(segment)]

    // One query per member: Firestore takes a single disjunctive clause, so the
    // owner cannot be an `in` while the terms are an `array-contains-any`. A
    // filter no term can express falls back on the visible set rather than
    // silently finding nothing — slow beats wrong.
    const candidates =
      terms.length > 0
        ? (
            await Promise.all(
              scope.memberIds.map((memberId) => BeverageQuery.bySearchTerms(memberId, terms)),
            )
          ).flat()
        : await BeverageQuery.allVisibleTo(userId)
    const items = await withSatellites(userId, candidates)
    // A housemate's wine only counts once it is placed in the shared cellar.
    const visible = items.filter((item) => item.userId === userId || item.cellar !== undefined)
    const hits = rankedHits(visible, query, filters)
    return { hits: hits.slice(0, limit), totalCount: hits.length }
  }

  // Attach the viewer's own satellites to the candidates, by id — never a scan.
  const withSatellites = async (userId: UserId, candidates: Beverage[]) => {
    const ids = candidates.map((wine) => wine.id)
    const owned = candidates.map((wine) => ({ id: wine.id, userId: wine.userId }))
    const [placements, tastings, gifts, recommendations] = await Promise.all([
      // Keyed by (owner, beverage), so a housemate's bottle resolves without a
      // household-wide scan.
      CellarQuery.placementsByOwnedBeverages(owned),
      TastingQuery.byBeverageIds(userId, ids),
      GiftQuery.byBeverageIds(userId, ids),
      RecommendationQuery.byBeverageIds(userId, ids),
    ])
    const cellar = indexByBeverageId(placements)
    const consumption = indexByBeverageId(tastings)
    const gift = indexByBeverageId(gifts)
    const recommendation = indexByBeverageId(recommendations)
    // Attach only the satellites that exist: no key rather than a null value.
    return candidates.map((wine) => {
      const item: SearchableWine = { ...wine }
      const bottle = cellar.get(wine.id)
      if (bottle) item.cellar = bottle
      const tasting = consumption.get(wine.id)
      if (tasting) item.consumption = tasting
      const given = gift.get(wine.id)
      if (given) item.gift = given
      const recommended = recommendation.get(wine.id)
      if (recommended) item.recommendation = recommended
      return item
    })
  }

  const indexByBeverageId = <T extends { beverageId: BeverageId }>(records: T[]) =>
    new Map(records.map((record) => [record.beverageId, record]))
}
