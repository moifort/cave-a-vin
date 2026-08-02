import Apollo
import Foundation

enum DashboardAPI {
    static func getData() async throws -> DashboardData {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.DashboardQuery()
        )
        let d = data.dashboard
        return DashboardData(
            bottleCount: d.bottleCount,
            capacity: d.capacity,
            totalValue: d.totalValue,
            readyToDrink: d.readyToDrink.map {
                DashboardWine(
                    id: $0.id,
                    name: $0.name,
                    beverageType: BeverageType(graphql: $0.beverageType),
                    color: $0.color.map { WineColor(graphql: $0) },
                    position: $0.position,
                    urgent: $0.urgent,
                    drinkUntil: $0.drinkUntil
                )
            },
            favorites: d.favorites.map {
                DashboardFavorite(
                    id: $0.id,
                    name: $0.name,
                    beverageType: BeverageType(graphql: $0.beverageType),
                    color: $0.color.map { WineColor(graphql: $0) },
                    vintage: $0.vintage,
                    estimatedPrice: $0.estimatedPrice,
                    tastingDate: $0.tastingDate.flatMap { GraphQLHelpers.parseISO8601($0) },
                    rating: $0.rating.map { Int($0) }
                )
            },
            lastBottle: d.lastBottle.map {
                DashboardEntry(
                    wine: DashboardEntryWine(
                        id: $0.wine.id,
                        name: $0.wine.name,
                        beverageType: BeverageType(graphql: $0.wine.beverageType),
                        color: $0.wine.color.map { WineColor(graphql: $0) },
                        vintage: $0.wine.vintage
                    ),
                    position: $0.position,
                    date: GraphQLHelpers.parseISO8601($0.date) ?? Date(),
                    rating: nil
                )
            },
            lastExit: d.lastExit.map { mapHistory($0) },
            history: d.history.map { mapHistory($0) }
        )
    }
}

private func mapHistory<T: DashboardJournalEvent>(_ e: T) -> DashboardHistoryEvent {
    DashboardHistoryEvent(
        type: e.eventType,
        date: GraphQLHelpers.parseISO8601(e.dateString) ?? Date(),
        wineId: e.wineIdString,
        wineName: e.wineNameString,
        wineBeverageType: e.wineBeverageTypeValue,
        wineColor: e.wineColorValue,
        position: e.positionString,
        rating: nil,
        memberName: e.memberNameValue
    )
}

protocol DashboardJournalEvent {
    var eventType: String { get }
    var dateString: String { get }
    var wineIdString: String { get }
    var wineNameString: String { get }
    var wineBeverageTypeValue: BeverageType { get }
    var wineColorValue: WineColor? { get }
    var positionString: String { get }
    /// The household member behind the move, nil when it was you.
    var memberNameValue: String? { get }
}

extension VinariumGraphQL.DashboardQuery.Data.Dashboard.LastExit: DashboardJournalEvent {
    var eventType: String {
        switch type { case .case(.in): return "in"; case .case(.out): return "out"; case .unknown: return "in" }
    }
    var dateString: String { date }
    var wineIdString: String { beverageId }
    var wineNameString: String { beverageName }
    var wineBeverageTypeValue: BeverageType { BeverageType(graphql: wineBeverageType) }
    var wineColorValue: WineColor? { wineColor.map { WineColor(graphql: $0) } }
    var positionString: String { position }
    var memberNameValue: String? { actor.isMine ? nil : actor.displayName }
}

extension VinariumGraphQL.DashboardQuery.Data.Dashboard.History: DashboardJournalEvent {
    var eventType: String {
        switch type { case .case(.in): return "in"; case .case(.out): return "out"; case .unknown: return "in" }
    }
    var dateString: String { date }
    var wineIdString: String { beverageId }
    var wineNameString: String { beverageName }
    var wineBeverageTypeValue: BeverageType { BeverageType(graphql: wineBeverageType) }
    var wineColorValue: WineColor? { wineColor.map { WineColor(graphql: $0) } }
    var positionString: String { position }
    var memberNameValue: String? { actor.isMine ? nil : actor.displayName }
}
