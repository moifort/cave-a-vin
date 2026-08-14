import Foundation

/// Which wine field the query matched — drives how a hit is grouped into a section.
enum SearchMatchedField: Sendable {
    case name, producer, subtype, color, beverageType, appellation, region, vintage
    case giftedBy, giftRecipient, recommender, tastingContact

    init(graphql: GraphQLEnum<VinariumGraphQL.SearchMatchedField>) {
        switch graphql {
        case .case(let value):
            switch value {
            case .name: self = .name
            case .producer: self = .producer
            case .subtype: self = .subtype
            case .color: self = .color
            case .beverageType: self = .beverageType
            case .appellation: self = .appellation
            case .region: self = .region
            case .vintage: self = .vintage
            case .giftedBy: self = .giftedBy
            case .giftRecipient: self = .giftRecipient
            case .recommender: self = .recommender
            case .tastingContact: self = .tastingContact
            }
        case .unknown:
            self = .name
        }
    }
}

/// A wine that matched the search plus the fields that matched it.
struct SearchHit: Identifiable, Sendable {
    let wine: Wine
    let matchedFields: [SearchMatchedField]
    var id: String { wine.id }
}

struct SearchResults: Sendable {
    let hits: [SearchHit]
    let totalCount: Int
}

/// Combinable facet filters sent alongside the text query.
struct SearchFilters: Equatable, Sendable {
    var colors: Set<WineColor> = []
    var beverageTypes: Set<BeverageType> = []
    var favorite = false
    var status: WineStatusFilter = .all
    var gifted = false

    var isActive: Bool {
        !colors.isEmpty || !beverageTypes.isEmpty || favorite || gifted || status != .all
    }
}
