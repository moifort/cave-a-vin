import Apollo
import Foundation

enum SearchAPI {
    /// The number of hits is left to the server, so it can be retuned without
    /// waiting for an App Store release.
    static func search(query: String, filters: SearchFilters) async throws
        -> SearchResults
    {
        let gqlQuery = VinariumGraphQL.SearchQuery(
            query: GraphQLHelpers.graphQLNullable(query.isEmpty ? nil : query),
            filters: .some(input(from: filters)),
            limit: .none
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: gqlQuery)
        return SearchResults(
            hits: data.searchBeverages.hits.map { hit in
                SearchHit(
                    wine: Wine(listFields: hit.wine.fragments.wineListFields),
                    matchedFields: hit.matchedFields.map { SearchMatchedField(graphql: $0) }
                )
            },
            totalCount: data.searchBeverages.totalCount
        )
    }

    /// Only active facets are sent; an inactive facet is omitted so the server
    /// leaves it unfiltered.
    private static func input(from f: SearchFilters) -> VinariumGraphQL.SearchFiltersInput {
        VinariumGraphQL.SearchFiltersInput(
            beverageTypes: f.beverageTypes.isEmpty
                ? .none : .some(f.beverageTypes.map { $0.graphQLValue }),
            colors: f.colors.isEmpty ? .none : .some(f.colors.map { $0.graphQLValue }),
            favorite: f.favorite ? .some(true) : .none,
            gifted: f.gifted ? .some(true) : .none,
            status: f.status == .all ? .none : .some(gqlStatus(f.status))
        )
    }

    private static func gqlStatus(
        _ status: WineStatusFilter
    ) -> GraphQLEnum<VinariumGraphQL.BeverageStatusFilter> {
        switch status {
        case .all: .case(.all)
        case .inCellar: .case(.inCellar)
        case .consumed: .case(.consumed)
        }
    }
}
