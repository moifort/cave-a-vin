import Apollo
import Foundation

/// One page of the wine list, mirroring the server's `Wines` payload.
struct WinePage {
    let items: [Wine]
    let hasMore: Bool
    let totalCount: Int
}

enum WineAPI {
    static func list(
        mode: WineListMode,
        sort: WineSort,
        sortDescending: Bool,
        statusFilter: WineStatusFilter,
        color: WineColor?,
        beverageType: BeverageType?,
        limit: Int,
        after: String?
    ) async throws -> WinePage {
        let query = VinariumGraphQL.WineListQuery(
            mode: .some(.case(gqlMode(mode))),
            status: .some(.case(gqlStatus(statusFilter))),
            color: color.map { .some(graphQLColor($0)) } ?? .none,
            beverageType: beverageType.map { .some($0.graphQLValue) } ?? .none,
            sort: .some(.case(gqlSort(sort))),
            order: .some(.case(sortDescending ? .desc : .asc)),
            limit: .some(Int32(limit)),
            after: GraphQLHelpers.graphQLNullable(after)
        )
        let data = try await GraphQLHelpers.fetch(GraphQLClient.shared.apollo, query: query)
        return WinePage(
            items: data.beverages.items.map { Wine(listFields: $0.fragments.wineListFields) },
            hasMore: data.beverages.hasMore,
            totalCount: data.beverages.totalCount
        )
    }

    static func getDetail(id: String) async throws -> UserWineDetail {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: VinariumGraphQL.WineDetailQuery(id: id)
        )
        guard let wine = data.beverage else { throw APIError.invalidResponse }
        return mapDetail(wine)
    }

    static func create(_ request: CreateWineRequest) async throws -> Wine {
        let input = addWineInput(from: request)
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.AddWineMutation(input: input)
        )
        let created = data.addBeverage
        let createdDetails = created.details?.asWineDetails
        return Wine(
            id: created.id,
            name: created.name,
            beverageType: BeverageType(graphql: created.beverageType),
            color: createdDetails?.color.map { WineColor(graphql: $0) },
            subtype: created.subtype.flatMap { BeverageSubtype(graphql: $0) },
            vintage: createdDetails?.vintage,
            createdAt: GraphQLHelpers.parseISO8601(created.createdAt) ?? Date(),
            updatedAt: GraphQLHelpers.parseISO8601(created.updatedAt) ?? Date()
        )
    }

    static func update(id: String, _ request: UpdateWineRequest) async throws -> Wine {
        let input = updateWineInput(from: request)
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.UpdateWineMutation(id: id, input: input)
        )
        let updated = data.updateBeverage
        let updatedDetails = updated.details?.asWineDetails
        return Wine(
            id: updated.id,
            name: updated.name,
            beverageType: BeverageType(graphql: updated.beverageType),
            color: updatedDetails?.color.map { WineColor(graphql: $0) },
            subtype: updated.subtype.flatMap { BeverageSubtype(graphql: $0) },
            vintage: updatedDetails?.vintage,
            createdAt: Date(),
            updatedAt: GraphQLHelpers.parseISO8601(updated.updatedAt) ?? Date()
        )
    }

    static func delete(id: String) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.DeleteWineMutation(id: id)
        )
    }

    static func scan(imageData: Data) async throws -> ScanResult {
        let base64 = imageData.base64EncodedString()
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.ScanWineMutation(imageBase64: base64)
        )
        let s = data.scanBeverage
        return ScanResult(
            recognized: s.recognized,
            name: s.name,
            beverageType: BeverageType(graphql: s.beverageType),
            domain: s.domain,
            vintage: s.vintage,
            appellation: s.appellation,
            region: s.region,
            country: s.country,
            color: s.color.map { WineColor(graphql: $0) },
            subtype: s.subtype.flatMap { BeverageSubtype(graphql: $0) },
            grapeVarieties: s.grapeVarieties ?? [],
            alcoholContent: s.alcoholContent,
            classification: s.classification,
            drinkFrom: s.drinkFrom,
            drinkUntil: s.drinkUntil,
            estimatedPrice: s.estimatedPrice
        )
    }

    /// Toggle the favorite (heart) flag without clobbering an existing tasting note.
    static func setFavorite(id: String, favorite: Bool) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.MarkFavoriteMutation(beverageId: id, favorite: favorite)
        )
    }

    /// Record a tasting note (rating, notes, favorite flag) for a wine.
    static func recordTasting(
        id: String,
        consumedDate: String? = nil,
        rating: Int? = nil,
        contacts: [String]? = nil,
        tastingNotes: String? = nil,
        favorite: Bool? = nil
    ) async throws {
        let input = VinariumGraphQL.TastingInput(
            consumedDate: GraphQLHelpers.graphQLNullable(consumedDate),
            contacts: GraphQLHelpers.graphQLNullable(contacts),
            favorite: GraphQLHelpers.graphQLNullable(favorite),
            rating: GraphQLHelpers.graphQLNullable(rating),
            tastingNotes: GraphQLHelpers.graphQLNullable(tastingNotes)
        )
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: VinariumGraphQL.RecordTastingMutation(beverageId: id, input: input)
        )
    }
}

// MARK: - Mapping helpers

private func graphQLColor(_ color: WineColor) -> GraphQLEnum<VinariumGraphQL.WineColor> {
    color.graphQLValue
}

private func gqlMode(_ mode: WineListMode) -> VinariumGraphQL.BeverageListMode {
    switch mode {
    case .all: .all
    case .favorites: .favorites
    case .gifted: .gifted
    case .recommended: .recommended
    }
}

private func gqlStatus(_ status: WineStatusFilter) -> VinariumGraphQL.BeverageStatusFilter {
    switch status {
    case .all: .all
    case .inCellar: .inCellar
    case .consumed: .consumed
    }
}

private func gqlSort(_ sort: WineSort) -> VinariumGraphQL.BeverageSort {
    switch sort {
    case .updatedAt: .updatedAt
    case .vintage: .vintage
    case .region: .region
    case .color: .color
    case .price: .price
    // « Par personne » est un groupement purement client, réservé aux modes
    // Offerts/Conseillés où le serveur renvoie le subset complet : le tri
    // serveur demandé est alors sans effet sur les sections.
    case .person: .updatedAt
    }
}

private func mapDetail(_ w: VinariumGraphQL.WineDetailQuery.Data.Beverage) -> UserWineDetail {
    let details = w.details?.asWineDetails
    return UserWineDetail(
        id: w.id,
        name: w.name,
        beverageType: BeverageType(graphql: w.beverageType),
        color: details?.color.map { WineColor(graphql: $0) },
        subtype: w.subtype.flatMap { BeverageSubtype(graphql: $0) },
        domain: w.producer,
        vintage: details?.vintage,
        appellation: details?.appellation,
        region: w.region,
        country: w.country,
        grapeVarieties: details?.grapeVarieties ?? [],
        alcoholContent: w.alcoholContent,
        classification: details?.classification,
        purchasePrice: w.purchase?.price,
        purchaseDate: w.purchase?.date,
        drinkFrom: details?.drinkWindow?.from,
        drinkUntil: details?.drinkWindow?.until,
        notes: w.notes,
        giftedBy: w.gift?.received?.from,
        createdAt: GraphQLHelpers.parseISO8601(w.createdAt) ?? Date(),
        updatedAt: GraphQLHelpers.parseISO8601(w.updatedAt) ?? Date(),
        cellar: w.cellar.map {
            CellarInfo(
                row: $0.rowLabel,
                col: $0.colLabel,
                dateIn: GraphQLHelpers.parseISO8601($0.createdAt) ?? Date(),
                dateOut: nil
            )
        },
        consumption: w.consumption.map {
            ConsumptionInfo(
                consumedDate: $0.consumedDate.flatMap { GraphQLHelpers.parseISO8601($0) },
                rating: $0.rating,
                tastingNotes: $0.tastingNotes,
                contacts: $0.contacts,
                favorite: $0.favorite
            )
        },
        // GiftInfo représente la facette « donné » (given) ; la provenance
        // « reçu de » vit dans giftedBy ci-dessus.
        gift: w.gift?.given.map {
            GiftInfo(
                giftedDate: GraphQLHelpers.parseISO8601($0.date) ?? Date(),
                recipientName: $0.recipientName
            )
        },
        recommendation: w.recommendation.map {
            RecommendationInfo(
                recommenderName: $0.recommenderName,
                comment: $0.comment
            )
        },
        latitude: w.place?.latitude,
        longitude: w.place?.longitude,
        placeName: w.place?.name,
        isMine: w.isMine,
        ownerName: w.ownerName
    )
}

private func addWineInput(from r: CreateWineRequest) -> VinariumGraphQL.AddBeverageInput {
    VinariumGraphQL.AddBeverageInput(
        alcoholContent: GraphQLHelpers.graphQLNullable(r.alcoholContent),
        appellation: GraphQLHelpers.graphQLNullable(r.appellation),
        beverageType: .some(r.beverageType.graphQLValue),
        classification: GraphQLHelpers.graphQLNullable(r.classification),
        color: r.color.map { .some(graphQLColor($0)) } ?? .none,
        country: GraphQLHelpers.graphQLNullable(r.country),
        drinkFrom: GraphQLHelpers.graphQLNullable(r.drinkFrom),
        drinkUntil: GraphQLHelpers.graphQLNullable(r.drinkUntil),
        giftedBy: GraphQLHelpers.graphQLNullable(r.giftedBy),
        grapeVarieties: GraphQLHelpers.graphQLNullable(r.grapeVarieties),
        latitude: GraphQLHelpers.graphQLNullable(r.latitude),
        longitude: GraphQLHelpers.graphQLNullable(r.longitude),
        name: r.name,
        notes: GraphQLHelpers.graphQLNullable(r.notes),
        placeName: GraphQLHelpers.graphQLNullable(r.placeName),
        producer: GraphQLHelpers.graphQLNullable(r.domain),
        purchaseDate: GraphQLHelpers.graphQLNullable(r.purchaseDate),
        purchasePrice: GraphQLHelpers.graphQLNullable(r.purchasePrice),
        region: GraphQLHelpers.graphQLNullable(r.region),
        subtype: r.subtype.map { .some($0.graphql) } ?? .none,
        vintage: GraphQLHelpers.graphQLNullable(r.vintage)
    )
}

private func updateWineInput(from r: UpdateWineRequest) -> VinariumGraphQL.UpdateBeverageInput {
    VinariumGraphQL.UpdateBeverageInput(
        appellation: GraphQLHelpers.graphQLNullable(r.appellation),
        beverageType: r.beverageType.map { .some($0.graphQLValue) } ?? .none,
        classification: GraphQLHelpers.graphQLNullable(r.classification),
        color: r.color.map { .some(graphQLColor($0)) } ?? .none,
        country: GraphQLHelpers.graphQLNullable(r.country),
        drinkFrom: GraphQLHelpers.graphQLNullable(r.drinkFrom),
        drinkUntil: GraphQLHelpers.graphQLNullable(r.drinkUntil),
        giftedBy: GraphQLHelpers.graphQLNullable(r.giftedBy),
        grapeVarieties: GraphQLHelpers.graphQLNullable(r.grapeVarieties),
        latitude: GraphQLHelpers.graphQLNullable(r.latitude),
        longitude: GraphQLHelpers.graphQLNullable(r.longitude),
        name: GraphQLHelpers.graphQLNullable(r.name),
        notes: GraphQLHelpers.graphQLNullable(r.notes),
        placeName: GraphQLHelpers.graphQLNullable(r.placeName),
        producer: GraphQLHelpers.graphQLNullable(r.domain),
        purchaseDate: GraphQLHelpers.graphQLNullable(r.purchaseDate),
        purchasePrice: GraphQLHelpers.graphQLNullable(r.purchasePrice),
        region: GraphQLHelpers.graphQLNullable(r.region),
        subtype: r.subtype.map { .some($0.graphql) } ?? .none,
        vintage: GraphQLHelpers.graphQLNullable(r.vintage)
    )
}
