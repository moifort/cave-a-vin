import Apollo
import Foundation

/// One page of cellar journal events.
struct HistoryPage {
    let events: [HistoryEvent]
    let hasMore: Bool
}

/// One page of cellar bottles.
struct BottlesPage {
    let bottles: [CellarBottle]
    let hasMore: Bool
}

/// The configured grid dimensions of the shared cellar.
struct CellarGridInfo {
    let rows: Int
    let cols: Int
}

enum CellarAPI {
    static func getBottles(limit: Int, after: String?) async throws -> BottlesPage {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.CellarBottlesQuery(
                limit: .some(Int32(limit)),
                after: GraphQLHelpers.graphQLNullable(after)
            )
        )
        let bottles = data.cellarBottles.items.map { b in
            let details = b.wine.details?.asWineDetails
            return CellarBottle(
                wineId: b.beverageId,
                wine: Wine(
                    id: b.wine.id,
                    name: b.wine.name,
                    beverageType: BeverageType(graphql: b.wine.beverageType),
                    color: details?.color.map { WineColor(graphql: $0) },
                    subtype: b.wine.subtype.flatMap { BeverageSubtype(graphql: $0) },
                    domain: b.wine.producer,
                    vintage: details?.vintage,
                    appellation: details?.appellation,
                    region: b.wine.region,
                    country: b.wine.country,
                    classification: details?.classification,
                    purchasePrice: b.wine.purchase?.price,
                    drinkFrom: details?.drinkWindow?.from,
                    drinkUntil: details?.drinkWindow?.until,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                rowLabel: b.rowLabel,
                colLabel: b.colLabel,
                createdAt: GraphQLHelpers.parseISO8601(b.createdAt) ?? Date(),
                ownerName: b.owner.isMine ? nil : b.owner.displayName
            )
        }
        return BottlesPage(bottles: bottles, hasMore: data.cellarBottles.hasMore)
    }

    /// Toutes les bouteilles de la cave (grille complète pour placer/déplacer une
    /// bouteille). La cave est bornée par sa capacité physique : une grande page
    /// la couvre entièrement.
    static func getAllBottles() async throws -> [CellarBottle] {
        try await getBottles(limit: 1000, after: nil).bottles
    }

    static func getHistory(limit: Int, offset: Int) async throws -> HistoryPage {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.CellarHistoryQuery(limit: .some(Int32(limit)), offset: .some(Int32(offset)))
        )
        let events = data.journalEvents.items.map { e in
            HistoryEvent(
                type: mapEventType(e.type),
                date: GraphQLHelpers.parseISO8601(e.date) ?? Date(),
                wineId: e.beverageId,
                wineName: e.beverageName,
                wineBeverageType: BeverageType(graphql: e.wineBeverageType),
                wineColor: e.wineColor.map { WineColor(graphql: $0) },
                position: e.position,
                memberName: e.actor.isMine ? nil : e.actor.displayName
            )
        }
        return HistoryPage(events: events, hasMore: data.journalEvents.hasMore)
    }

    static func info() async throws -> CellarGridInfo {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.CellarGridInfoQuery()
        )
        return CellarGridInfo(rows: Int(data.cellarInfo.rows), cols: Int(data.cellarInfo.cols))
    }

    static func suggest() async throws -> CellarSuggestion {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.SuggestCellarPositionQuery()
        )
        guard let position = data.suggestCellarPosition else {
            throw APIError.invalidResponse
        }
        return CellarSuggestion(row: position.rowLabel, col: position.colLabel)
    }

    /// Place a bottle at a grid slot named the way the UI shows it: row "A", column 1.
    static func place(wineId: String, rowLabel: String, colLabel: Int) async throws {
        let (row, col) = gridIndices(rowLabel: rowLabel, colLabel: colLabel)
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.PlaceBottleMutation(beverageId: wineId, row: row, col: col)
        )
    }

    /// Move a bottle to a grid slot named the way the UI shows it: row "A", column 1.
    static func move(wineId: String, rowLabel: String, colLabel: Int) async throws {
        let (row, col) = gridIndices(rowLabel: rowLabel, colLabel: colLabel)
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.MoveBottleMutation(beverageId: wineId, row: row, col: col)
        )
    }

    static func remove(
        wineId: String,
        consumedDate: String? = nil,
        rating: Int? = nil,
        tastingNotes: String? = nil,
        contacts: [String]? = nil
    ) async throws {
        let input = VinariumGraphQL.ConsumptionInput(
            consumedDate: GraphQLHelpers.graphQLNullable(consumedDate),
            contacts: GraphQLHelpers.graphQLNullable(contacts),
            favorite: .none,
            rating: GraphQLHelpers.graphQLNullable(rating),
            tastingNotes: GraphQLHelpers.graphQLNullable(tastingNotes)
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.ConsumeBottleMutation(beverageId: wineId, input: input)
        )
    }

    static func gift(
        wineId: String,
        giftedDate: String,
        recipientName: String?
    ) async throws {
        let input = VinariumGraphQL.GiftInput(
            giftedDate: giftedDate,
            recipientName: GraphQLHelpers.graphQLNullable(recipientName)
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.GiftBottleMutation(beverageId: wineId, input: input)
        )
    }
}

/// The grid indices behind a slot's labels. Both axes are labelled for reading and
/// stored 0-based: the server mirrors rowLabel = String.fromCharCode(65 + row) and
/// colLabel = col + 1, so "A" -> 0 and column 1 -> 0. Converting the row alone would
/// shift every bottle one column to the right of the slot that was picked.
private func gridIndices(rowLabel: String, colLabel: Int) -> (row: Int32, col: Int32) {
    let rowScalar = rowLabel.unicodeScalars.first.map { Int($0.value) - 65 } ?? 0
    return (Int32(max(0, rowScalar)), Int32(max(0, colLabel - 1)))
}

private func mapEventType(_ graphql: GraphQLEnum<VinariumGraphQL.JournalEventType>) -> HistoryEventType {
    switch graphql {
    case .case(.in): return .entry
    case .case(.out): return .exit
    case .unknown: return .entry
    }
}
