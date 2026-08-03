import type { BeverageStatusFilter, BeverageType, WineColor } from '~/domain/beverage/types'
import { builder } from '~/domain/shared/graphql/builder'
import { SearchQuery } from '../../query'
import type { SearchFilters } from '../../types'
import { SearchFiltersInput } from './inputs'
import { SearchResultsType } from './types'

builder.queryField('searchBeverages', (t) =>
  t.field({
    type: SearchResultsType,
    description:
      'Relevance-ranked faceted search across the whole collection.\n\n' +
      'Matches on name, producer, subtype, region, vintage or associated person, ranked by ' +
      'relevance. The words of the query are matched independently and in any order, and each ' +
      'one has to match something. Words match whole, so a partially typed word finds nothing; ' +
      "a vintage also matches by prefix. Spans the viewer's own wines plus household members' " +
      "wines placed in the shared cellar; tastings, gifts and recommendations stay the viewer's " +
      'own. An empty query with facet filters browses by filters alone; an empty query with no ' +
      'filter returns nothing.',
    args: {
      query: t.arg.string({
        description:
          'Free-text query, case- and accent-insensitive, word order free, whole words only; ' +
          'empty to browse by filters',
      }),
      filters: t.arg({
        type: SearchFiltersInput,
        description: 'Combinable facet filters applied on top of the text query',
      }),
      limit: t.arg.int({
        defaultValue: 20,
        description: 'Maximum number of hits returned (defaults to 20)',
      }),
    },
    resolve: async (_root, args, { userId }) => {
      const filters: SearchFilters = {
        colors: (args.filters?.colors as WineColor[] | null) ?? undefined,
        beverageTypes: (args.filters?.beverageTypes as BeverageType[] | null) ?? undefined,
        favorite: args.filters?.favorite ?? undefined,
        status: (args.filters?.status as BeverageStatusFilter | null) ?? undefined,
        gifted: args.filters?.gifted ?? undefined,
      }
      return SearchQuery.acrossCollections(userId, {
        query: args.query ?? '',
        filters,
        limit: args.limit ?? 20,
      })
    },
  }),
)
