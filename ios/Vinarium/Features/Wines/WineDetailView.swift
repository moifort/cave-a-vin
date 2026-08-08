import SwiftUI

struct WineDetailView: View {
    let wineId: String
    var onRemoved: (() -> Void)?
    var onUpdated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: UserWineDetail?
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var error: String?
    @State private var showConsumption = false
    @State private var showRemovalChoice = false
    @State private var showGift = false
    @State private var showDeleteConfirmation = false
    @State private var showPlacement = false
    @State private var showMove = false
    @State private var showFavorite = false
    @State private var showRecommendation = false
    @State private var isEditing = false
    @State private var showLocationEditor = false
    @State private var sheetError = ErrorPresenter()
    @State private var actionError = ErrorPresenter()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingStateView()
                } else if let detail {
                    if isEditing {
                        WineEditForm(
                            initial: Self.editFields(from: detail),
                            onSave: { submission in
                                try await save(submission, of: detail)
                                self.detail = try await WineAPI.getDetail(id: wineId)
                                isEditing = false
                                onUpdated?()
                            },
                            onCancel: { isEditing = false }
                        )
                    } else {
                        WineDetailPage(
                            content: Self.mapContent(detail),
                            onRemoveRequested: { showRemovalChoice = true },
                            onEditLocation: { showLocationEditor = true },
                            onRefresh: { await loadData() }
                        )
                    }
                } else if let error {
                    ContentUnavailableView(
                        "Erreur",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isEditing {
                    readToolbar
                }
            }
            // Menu actions (favorite, deletion, …) close the menu before the mutation
            // leaves, and post-mutation refetches keep the content on screen: in both
            // cases the network call is made visible by a scrim and a spinner.
            .overlay {
                if actionError.isRunning || isRefreshing {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
            .disabled(actionError.isRunning || isRefreshing)
            .errorAlert(actionError)
            .task {
                await loadData()
            }
            .sheet(isPresented: $showConsumption) {
                if let detail {
                    ConsumptionSheet { date, rating, notes, contacts in
                        let formatter = ISO8601DateFormatter()
                        await sheetError.run {
                            _ = try await CellarAPI.remove(
                                wineId: detail.id,
                                consumedDate: formatter.string(from: date),
                                rating: rating,
                                tastingNotes: notes,
                                contacts: contacts.isEmpty ? nil : contacts
                            )
                        } onSuccess: {
                            showConsumption = false
                            dismiss()
                            onRemoved?()
                        }
                    }
                    .presentationDetents([.height(550)])
                    .errorAlert(sheetError)
                }
            }
            .sheet(isPresented: $showGift) {
                if let detail {
                    GiftSheet { date, recipientName in
                        let formatter = ISO8601DateFormatter()
                        await sheetError.run {
                            _ = try await CellarAPI.gift(
                                wineId: detail.id,
                                giftedDate: formatter.string(from: date),
                                recipientName: recipientName
                            )
                        } onSuccess: {
                            showGift = false
                            dismiss()
                            onRemoved?()
                        }
                    }
                    .presentationDetents([.height(250)])
                    .errorAlert(sheetError)
                }
            }
            .sheet(isPresented: $showPlacement) {
                if let detail {
                    NavigationStack {
                        CellarPlacementView(
                            wineId: detail.id,
                            wineName: detail.name,
                            beverageType: detail.beverageType,
                            wineColor: detail.color,
                            wineVintage: detail.vintage,
                            onCancel: { showPlacement = false }
                        ) { _ in
                            showPlacement = false
                            dismiss()
                            onRemoved?()
                        }
                    }
                }
            }
            .sheet(isPresented: $showMove) {
                if let detail, let cellar = detail.cellar {
                    BottleMoveView(
                        wineId: detail.id,
                        wineName: detail.name,
                        wineBeverageType: detail.beverageType,
                        wineColor: detail.color,
                        wineVintage: detail.vintage,
                        currentRow: cellar.row,
                        currentCol: cellar.col,
                        onCancel: { showMove = false }
                    ) {
                        showMove = false
                        Task {
                            await loadData()
                            onUpdated?()
                        }
                    }
                }
            }
            .sheet(isPresented: $showFavorite) {
                if let detail {
                    FavoriteSheet { date, contacts, notes, rating in
                        let formatter = ISO8601DateFormatter()
                        await sheetError.run {
                            try await WineAPI.recordTasting(
                                id: detail.id,
                                consumedDate: formatter.string(from: date),
                                rating: rating == 0 ? nil : rating,
                                contacts: contacts.isEmpty ? nil : contacts,
                                tastingNotes: notes,
                                favorite: true
                            )
                        } onSuccess: {
                            showFavorite = false
                            Task {
                                await loadData()
                                onUpdated?()
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .errorAlert(sheetError)
                }
            }
            .sheet(isPresented: $showRecommendation) {
                if let detail {
                    RecommendationSheet { recommenderName, comment in
                        await sheetError.run {
                            try await RecommendationAPI.create(
                                wineId: detail.id,
                                recommenderName: recommenderName,
                                comment: comment
                            )
                        } onSuccess: {
                            showRecommendation = false
                            Task {
                                await loadData()
                                onUpdated?()
                            }
                        }
                    }
                    .presentationDetents([.medium])
                    .errorAlert(sheetError)
                }
            }
            .sheet(isPresented: $showLocationEditor) {
                if let detail {
                    LocationEditorSheet(initial: Self.locationDraft(from: detail)) { draft in
                        // "Aucun lieu" has to say so out loud: an absent coordinate
                        // reads as "unchanged" and would leave the old pin in place.
                        let request = UpdateWineRequest(
                            latitude: draft?.latitude,
                            longitude: draft?.longitude,
                            placeName: draft?.placeName,
                            cleared: draft == nil ? [.latitude, .longitude, .placeName] : []
                        )
                        await sheetError.run {
                            _ = try await WineAPI.update(id: detail.id, request)
                        } onSuccess: {
                            showLocationEditor = false
                            Task {
                                await loadData()
                                onUpdated?()
                            }
                        }
                    }
                    .errorAlert(sheetError)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var readToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
        }
        if let cellar = detail?.cellar, cellar.dateOut == nil {
            ToolbarItemGroup {
                Button("Déplacer", systemImage: "arrow.left.arrow.right") {
                    showMove = true
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("move-bottle-button")

                Button("Sortir", systemImage: "arrow.up") {
                    showRemovalChoice = true
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("remove-from-cellar-button")
                .confirmationDialog(
                    "Sortir de la cave",
                    isPresented: $showRemovalChoice,
                    titleVisibility: .visible
                ) {
                    Button("Consommer") { showConsumption = true }
                        .accessibilityIdentifier("choice-consume")
                    Button("Offrir") { showGift = true }
                        .accessibilityIdentifier("choice-gift")
                } message: {
                    Text("Comment souhaitez-vous sortir ce vin ?")
                }
            }
        }
        if let detail, detail.isMine, detail.cellar == nil, detail.recommendation != nil {
            ToolbarItemGroup {
                ToolbarIconButton(title: "Ajouter à la cave", systemImage: "plus") {
                    showPlacement = true
                }

                AsyncToolbarButton(title: "Ajouter aux favoris", systemImage: "heart") {
                    await actionError.run {
                        try await WineAPI.setFavorite(id: detail.id, favorite: true)
                    } onSuccess: {
                        dismiss()
                        onRemoved?()
                    }
                }
            }
        }
        if let detail {
            let isFavorite = detail.consumption?.favorite == true
            let canOfferFromCellar = detail.cellar != nil && detail.cellar?.dateOut == nil

            ToolbarItemGroup {
                Menu {
                    if detail.isMine {
                        Button("Modifier", systemImage: "pencil") {
                            isEditing = true
                        }
                    }

                    Section {
                        if isFavorite {
                            Button {
                                Task {
                                    await actionError.run {
                                        try await WineAPI.setFavorite(id: detail.id, favorite: false)
                                    } onSuccess: {
                                        Task {
                                            await loadData()
                                            onUpdated?()
                                        }
                                    }
                                }
                            } label: {
                                Label("Retirer des favoris", systemImage: "heart.slash")
                            }
                            .accessibilityIdentifier("menu-favorite-button")
                        } else {
                            Button {
                                showFavorite = true
                            } label: {
                                Label("Ajouter aux favoris", systemImage: "heart")
                            }
                            .accessibilityIdentifier("menu-favorite-button")
                        }

                        if detail.isMine {
                            Button {
                                showRecommendation = true
                            } label: {
                                Label("Conseillé par un ami", systemImage: "person.badge.plus")
                            }
                            .accessibilityIdentifier("menu-recommendation-button")
                        }

                        if canOfferFromCellar {
                            Button {
                                showGift = true
                            } label: {
                                Label("Offrir", systemImage: "gift")
                            }
                            .accessibilityIdentifier("menu-gift-button")
                        }
                    }

                    if detail.isMine {
                        Button("Supprimer", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("delete-wine-button")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityIdentifier("wine-detail-menu")
                .confirmationDialog(
                    "Supprimer ce vin ?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible,
                    presenting: detail
                ) { detail in
                    Button("Supprimer", role: .destructive) {
                        Task {
                            await actionError.run {
                                try await WineAPI.delete(id: detail.id)
                            } onSuccess: {
                                dismiss()
                                onRemoved?()
                            }
                        }
                    }
                    .accessibilityIdentifier("choice-delete")
                } message: { _ in
                    Text("Cette action est irréversible. Le vin sera supprimé de votre collection, de la cave et de toutes les données associées.")
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadData() async {
        // Post-mutation refresh: keep the content on screen and show the scrim rather
        // than replacing the whole page with a spinner.
        if detail != nil { isRefreshing = true }
        defer { isRefreshing = false }
        do {
            let loadedDetail = try await WineAPI.getDetail(id: wineId)
            detail = loadedDetail
            isLoading = false
        } catch {
            self.error = reportError(error)
            isLoading = false
        }
    }

    /// The sheet edits one screen but three records, so the form's save is three
    /// writes. The tasting note and the recommendation are only written when the
    /// user actually touched them: an untouched wine must not grow an empty tasting
    /// note just because its name was corrected.
    private func save(_ submission: WineEditSubmission, of detail: UserWineDetail) async throws {
        _ = try await WineAPI.update(id: detail.id, submission.wine)

        let initial = Self.editFields(from: detail)
        if submission.tasting != initial.tasting {
            let tasting = submission.tasting
            try await WineAPI.recordTasting(
                id: detail.id,
                consumedDate: tasting.consumedDate.map { ISO8601DateFormatter().string(from: $0) },
                rating: tasting.rating == 0 ? nil : tasting.rating,
                contacts: tasting.contacts,
                // An emptied comment is sent as such: that is how it gets erased.
                tastingNotes: tasting.tastingNotes
            )
        }

        if let gift = submission.gift, gift != initial.gift {
            try await WineAPI.updateGift(
                id: detail.id,
                recipientName: gift.recipientName.isEmpty ? nil : gift.recipientName,
                giftedDate: ISO8601DateFormatter().string(from: gift.date)
            )
        }

        if submission.recommendation != initial.recommendation {
            let reco = submission.recommendation
            try await RecommendationAPI.create(
                wineId: detail.id,
                recommenderName: reco.recommenderName.isEmpty ? nil : reco.recommenderName,
                comment: reco.comment.isEmpty ? nil : reco.comment
            )
        }
    }

    private static func locationDraft(from detail: UserWineDetail) -> TastingLocationDraft? {
        guard let latitude = detail.latitude, let longitude = detail.longitude else { return nil }
        return TastingLocationDraft(
            latitude: latitude,
            longitude: longitude,
            placeName: detail.placeName
        )
    }

    private static func mapContent(_ detail: UserWineDetail) -> WineDetailContent.Content {
        let formatter: (Date) -> String = { $0.formatted(date: .abbreviated, time: .omitted) }
        return WineDetailContent.Content(
            beverageType: detail.beverageType,
            color: detail.color,
            subtype: detail.subtype,
            name: detail.name,
            domain: detail.domain,
            vintage: detail.vintage,
            appellation: detail.appellation,
            region: detail.region,
            country: detail.country,
            classification: detail.classification,
            placeName: detail.placeName,
            latitude: detail.latitude,
            longitude: detail.longitude,
            alcoholContent: detail.alcoholContent,
            purchasePrice: detail.purchasePrice,
            purchaseDate: detail.purchaseDate,
            grapeVarieties: detail.grapeVarieties,
            drinkFrom: detail.drinkFrom,
            drinkUntil: detail.drinkUntil,
            giftedBy: detail.giftedBy,
            notes: detail.notes,
            cellar: detail.cellar.map { cellar in
                .init(
                    position: "\(cellar.row)\(cellar.col)",
                    dateIn: formatter(cellar.dateIn),
                    dateOut: cellar.dateOut.map(formatter),
                    isInCellar: cellar.dateOut == nil
                )
            },
            consumption: detail.consumption.map { consumption in
                .init(
                    consumedDate: consumption.consumedDate.map(formatter),
                    rating: consumption.rating,
                    tastingNotes: consumption.tastingNotes,
                    contacts: consumption.contacts
                )
            },
            gift: detail.gift.map { gift in
                .init(giftedDate: formatter(gift.giftedDate), recipientName: gift.recipientName)
            },
            recommendation: detail.recommendation.map { reco in
                .init(recommenderName: reco.recommenderName, comment: reco.comment)
            },
            ownerName: detail.ownerName
        )
    }

    private static func editFields(from detail: UserWineDetail) -> WineEditForm.Fields {
        var parsedPurchaseDate: Date?
        if let dateString = detail.purchaseDate {
            parsedPurchaseDate = ISO8601DateFormatter().date(from: dateString)
        }
        return WineEditForm.Fields(
            name: detail.name,
            beverageType: detail.beverageType,
            color: detail.color ?? .red,
            subtype: detail.subtype,
            domain: detail.domain ?? "",
            vintage: detail.vintage.map(String.init) ?? "",
            appellation: detail.appellation ?? "",
            region: detail.region ?? "",
            country: detail.country ?? "",
            classification: detail.classification ?? "",
            grapeVarieties: detail.grapeVarieties.joined(separator: ", "),
            purchasePrice: detail.purchasePrice.map(Money.editableTextFromEur) ?? "",
            purchaseDate: parsedPurchaseDate,
            drinkFrom: detail.drinkFrom.map(String.init) ?? "",
            drinkUntil: detail.drinkUntil.map(String.init) ?? "",
            giftedBy: detail.giftedBy ?? "",
            notes: detail.notes ?? "",
            alcoholContent: detail.alcoholContent.map(Money.decimalText) ?? "",
            place: Self.locationDraft(from: detail),
            gift: detail.gift.map {
                GiftDraft(recipientName: $0.recipientName ?? "", date: $0.giftedDate)
            },
            tasting: TastingDraft(
                rating: detail.consumption?.rating ?? 0,
                consumedDate: detail.consumption?.consumedDate,
                contacts: detail.consumption?.contacts ?? [],
                tastingNotes: detail.consumption?.tastingNotes ?? ""
            ),
            recommendation: RecommendationDraft(
                recommenderName: detail.recommendation?.recommenderName ?? "",
                comment: detail.recommendation?.comment ?? ""
            )
        )
    }
}

#Preview("Bottle taken out") {
    WineDetailView(wineId: "5d288fc9-864d-4633-862a-b4410cf8b64a")
}

#Preview("In cellar") {
    WineDetailView(wineId: "c2f5486a-29d6-4a32-b3e9-323ab1bee3d1")
}

#Preview("Recommend") {
    WineDetailView(wineId: "19fe3138-e125-4df9-afe6-90e1505a0326")
}
