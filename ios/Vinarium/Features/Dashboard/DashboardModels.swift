import Foundation

struct DashboardData: Codable, Sendable {
    let bottleCount: Int
    let capacity: Int
    let totalValue: Double
    let readyToDrink: [DashboardWine]
    let favorites: [DashboardFavorite]
    let lastBottle: DashboardEntry?
    let lastExit: DashboardHistoryEvent?
    let history: [DashboardHistoryEvent]
}

struct DashboardFavorite: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let beverageType: BeverageType
    let color: WineColor?
    let vintage: Int?
    let estimatedPrice: Double?
    let tastingDate: Date?
    let rating: Int?
}

struct DashboardWine: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let beverageType: BeverageType
    let color: WineColor?
    let position: String
    let urgent: Bool
    let drinkUntil: Int?
}

struct DashboardEntry: Codable, Sendable {
    let wine: DashboardEntryWine
    let position: String
    let date: Date
    let rating: Int?
}

struct DashboardEntryWine: Codable, Sendable {
    let id: String
    let name: String
    let beverageType: BeverageType
    let color: WineColor?
    let vintage: Int?
}

struct DashboardHistoryEvent: Codable, Identifiable, Sendable {
    let type: String
    let date: Date
    let wineId: String
    let wineName: String
    let wineBeverageType: BeverageType
    let wineColor: WineColor?
    let position: String
    let rating: Int?
    /// The household member behind the move, nil when it was you.
    let memberName: String?

    var id: String { "\(type)-\(wineName)-\(date.timeIntervalSince1970)" }

    var isEntry: Bool { type == "in" }
}
