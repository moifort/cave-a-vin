import SwiftUI

/// What the wine sheet stores in three separate records, as the form hands it back.
struct WineEditSubmission {
    var wine: UpdateWineRequest
    var tasting: TastingDraft
    var recommendation: RecommendationDraft
    /// Only for a bottle already given away — the form corrects that record, it
    /// never creates one (giving a bottle away is a cellar action).
    var gift: GiftDraft?
}

struct GiftDraft: Equatable {
    var recipientName: String = ""
    var date = Date()
}

/// A rating of 0 means the wine was never scored.
struct TastingDraft: Equatable {
    var rating: Int = 0
    var consumedDate: Date?
    var contacts: [String] = []
    var tastingNotes: String = ""
}

struct RecommendationDraft: Equatable {
    var recommenderName: String = ""
    var comment: String = ""
}

struct WineEditForm: View {
    let initial: Fields
    let onSave: (WineEditSubmission) async throws -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var beverageType: BeverageType
    @State private var color: WineColor
    @State private var subtype: BeverageSubtype?
    @State private var domain: String
    @State private var vintage: String
    @State private var appellation: String
    @State private var region: String
    @State private var country: String
    @State private var classification: String
    @State private var grapeVarieties: String
    @State private var purchasePrice: String
    @State private var purchaseDate: Date?
    @State private var drinkFrom: String
    @State private var drinkUntil: String
    @State private var giftedBy: String
    @State private var notes: String
    @State private var alcoholContent: String
    @State private var tasting: TastingDraft
    @State private var recommendation: RecommendationDraft
    @State private var gift: GiftDraft?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showGiftedByPicker = false
    @State private var showContactPicker = false
    @State private var showRecommenderPicker = false
    @State private var showPlacePicker = false
    @State private var place: TastingLocationDraft?

    init(
        initial: Fields,
        onSave: @escaping (WineEditSubmission) async throws -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial.name)
        _beverageType = State(initialValue: initial.beverageType)
        _color = State(initialValue: initial.color)
        _subtype = State(initialValue: initial.subtype)
        _domain = State(initialValue: initial.domain)
        _vintage = State(initialValue: initial.vintage)
        _appellation = State(initialValue: initial.appellation)
        _region = State(initialValue: initial.region)
        _country = State(initialValue: initial.country)
        _classification = State(initialValue: initial.classification)
        _grapeVarieties = State(initialValue: initial.grapeVarieties)
        _purchasePrice = State(initialValue: initial.purchasePrice)
        _purchaseDate = State(initialValue: initial.purchaseDate)
        _drinkFrom = State(initialValue: initial.drinkFrom)
        _drinkUntil = State(initialValue: initial.drinkUntil)
        _giftedBy = State(initialValue: initial.giftedBy)
        _notes = State(initialValue: initial.notes)
        _alcoholContent = State(initialValue: initial.alcoholContent)
        _place = State(initialValue: initial.place)
        _tasting = State(initialValue: initial.tasting)
        _recommendation = State(initialValue: initial.recommendation)
        _gift = State(initialValue: initial.gift)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    TextField("Nom", text: $name)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Nom", systemImage: "wineglass")
                }

                Picker(selection: $beverageType) {
                    ForEach(BeverageType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                } label: {
                    Label("Type", systemImage: "square.grid.2x2")
                }

                if beverageType == .wine {
                    Picker(selection: $color) {
                        ForEach(WineColor.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    } label: {
                        Label("Couleur", systemImage: "paintpalette")
                    }
                }

                Picker(selection: $subtype) {
                    Text("—").tag(BeverageSubtype?.none)
                    ForEach(BeverageSubtype.allowed(for: beverageType)) { s in
                        Text(s.label(for: beverageType)).tag(BeverageSubtype?.some(s))
                    }
                } label: {
                    Label("Sous-type", systemImage: "tag")
                }

                LabeledContent {
                    TextField(beverageType.producerLabel, text: $domain)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label(beverageType.producerLabel, systemImage: "building.2")
                }

                LabeledContent {
                    TextField("Année", text: $vintage)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Millésime", systemImage: "calendar")
                }
            } header: {
                Text("Informations principales")
            }

            Section {
                if beverageType == .wine {
                    LabeledContent {
                        TextField("Appellation", text: $appellation)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Appellation", systemImage: "seal")
                    }
                }

                LabeledContent {
                    TextField("Région", text: $region)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Région", systemImage: "map")
                }

                LabeledContent {
                    TextField("Pays", text: $country)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Pays", systemImage: "globe.europe.africa")
                }

                if beverageType == .wine {
                    LabeledContent {
                        TextField("Classification", text: $classification)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Classification", systemImage: "rosette")
                    }
                }

                // The place is picked on a map rather than typed, so the row opens the
                // same search sheet the wine sheet uses; nothing is written until save.
                Button {
                    showPlacePicker = true
                } label: {
                    LabeledContent {
                        HStack(spacing: 4) {
                            Text(place?.placeName ?? "Aucun lieu")
                                .foregroundStyle(place == nil ? .secondary : .primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    } label: {
                        Label("Lieu de dégustation", systemImage: "mappin.and.ellipse")
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Origine")
            }

            Section {
                if beverageType == .wine {
                    LabeledContent {
                        TextField("Cépages", text: $grapeVarieties)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Cépages", systemImage: "leaf")
                    }
                }

                LabeledContent {
                    HStack(spacing: 4) {
                        TextField("0", text: $alcoholContent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("% vol")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Degré", systemImage: "drop")
                }

                LabeledContent {
                    HStack(spacing: 4) {
                        TextField("0", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(Money.displayCurrencySymbol)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Prix", systemImage: "eurosign.circle")
                }

                LabeledContent {
                    if let date = Binding($purchaseDate) {
                        HStack {
                            DatePicker("", selection: date, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                            Button {
                                purchaseDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button("Ajouter") {
                            purchaseDate = Date()
                        }
                    }
                } label: {
                    Label("Date d'achat", systemImage: "cart")
                }
            } header: {
                Text("Détails")
            }

            if beverageType == .wine {
                Section {
                    LabeledContent {
                        TextField("Année", text: $drinkFrom)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("À partir de", systemImage: "hourglass.bottomhalf.filled")
                    }

                    LabeledContent {
                        TextField("Année", text: $drinkUntil)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Jusqu'à", systemImage: "hourglass.tophalf.filled")
                    }
                } header: {
                    Text("Garde")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Note", systemImage: "star")
                        .foregroundStyle(.secondary)
                    // A score already recorded can be raised or lowered, never erased:
                    // the API merges the fields it receives and has no "no score" value.
                    InteractiveStarRating(
                        rating: $tasting.rating,
                        allowsUnset: initial.tasting.rating == 0
                    )
                }
                .padding(.vertical, 4)

                LabeledContent {
                    if let date = Binding($tasting.consumedDate) {
                        DatePicker("", selection: date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                    } else {
                        Button("Ajouter") { tasting.consumedDate = Date() }
                    }
                } label: {
                    Label("Dégustée le", systemImage: "calendar")
                }

                HStack {
                    Label("Avec", systemImage: "person.2")
                    Spacer()
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Ajouter", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
                ForEach(tasting.contacts, id: \.self) { contact in
                    HStack {
                        Text(contact)
                        Spacer()
                        Button {
                            tasting.contacts.removeAll { $0 == contact }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Commentaires", systemImage: "text.quote")
                        .foregroundStyle(.secondary)
                    TextField("Vos impressions, arômes, accords...", text: $tasting.tastingNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Dégustation")
            }

            Section {
                HStack {
                    Label("Offert par", systemImage: "gift")
                    TextField("Nom", text: $giftedBy)
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
                    Button {
                        showGiftedByPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Cadeau")
            }

            if let giftBinding = Binding($gift) {
                Section {
                    HStack {
                        Label("Offert à", systemImage: "gift")
                        TextField("Nom", text: giftBinding.recipientName)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent {
                        DatePicker("", selection: giftBinding.date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                    } label: {
                        Label("Offert le", systemImage: "calendar")
                    }
                } header: {
                    Text("Bouteille offerte")
                }
            }

            Section {
                HStack {
                    Label("Conseillé par", systemImage: "person.badge.plus")
                    TextField("Nom", text: $recommendation.recommenderName)
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
                    Button {
                        showRecommenderPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Commentaire", systemImage: "text.quote")
                        .foregroundStyle(.secondary)
                    TextField("Ce qu'on vous en a dit", text: $recommendation.comment, axis: .vertical)
                        .lineLimit(2...5)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Recommandation")
            }

            Section {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Notes")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) {
                    onCancel()
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Enregistrer", systemImage: "checkmark") {
                        Task { await save() }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .sheet(isPresented: $showGiftedByPicker) {
            ContactPicker { giftedBy = $0 }
        }
        .sheet(isPresented: $showPlacePicker) {
            LocationEditorSheet(initial: place) { draft in
                place = draft
            }
        }
        .sheet(isPresented: $showRecommenderPicker) {
            ContactPicker { recommendation.recommenderName = $0 }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker { name in
                if !tasting.contacts.contains(name) { tasting.contacts.append(name) }
            }
        }
        // A subtype inherited from another beverage type no longer makes sense.
        .onChange(of: beverageType) {
            if let current = subtype, !BeverageSubtype.allowed(for: beverageType).contains(current) {
                subtype = nil
            }
        }
    }

    private func save() async {
        isSaving = true
        let varieties = grapeVarieties
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let isWine = beverageType == .wine
        let request = UpdateWineRequest(
            name: name,
            beverageType: beverageType,
            color: isWine ? color : nil,
            subtype: subtype,
            domain: domain.isEmpty ? nil : domain,
            vintage: Int(vintage),
            appellation: isWine && !appellation.isEmpty ? appellation : nil,
            region: region.isEmpty ? nil : region,
            country: country.isEmpty ? nil : country,
            grapeVarieties: isWine && !varieties.isEmpty ? varieties : nil,
            classification: isWine && !classification.isEmpty ? classification : nil,
            alcoholContent: Money.number(alcoholContent),
            // The field is shown and typed in the display currency; store euros.
            purchasePrice: Money.number(purchasePrice).map(Money.toEur),
            purchaseDate: purchaseDate.map { ISO8601DateFormatter().string(from: $0) },
            drinkFrom: Int(drinkFrom),
            drinkUntil: Int(drinkUntil),
            giftedBy: giftedBy.isEmpty ? nil : giftedBy,
            notes: notes.isEmpty ? nil : notes,
            latitude: place?.latitude,
            longitude: place?.longitude,
            placeName: place?.placeName,
            cleared: emptiedFields(isWine: isWine, varieties: varieties)
        )

        do {
            try await onSave(
                WineEditSubmission(
                    wine: request,
                    tasting: tasting,
                    recommendation: recommendation,
                    gift: gift
                )
            )
        } catch {
            saveError = reportError(error)
        }
        isSaving = false
    }

    /// Every field the form owns and the user left empty. Naming one that was
    /// already empty costs nothing — the server erases what is no longer there.
    private func emptiedFields(isWine: Bool, varieties: [String]) -> Set<ClearedWineField> {
        var emptied: Set<ClearedWineField> = []
        if domain.isEmpty { emptied.insert(.producer) }
        if region.isEmpty { emptied.insert(.region) }
        if country.isEmpty { emptied.insert(.country) }
        if notes.isEmpty { emptied.insert(.notes) }
        if alcoholContent.isEmpty { emptied.insert(.alcoholContent) }
        if purchasePrice.isEmpty { emptied.insert(.purchasePrice) }
        if purchaseDate == nil { emptied.insert(.purchaseDate) }
        if vintage.isEmpty { emptied.insert(.vintage) }
        if subtype == nil { emptied.insert(.subtype) }
        if place == nil { emptied.formUnion([.latitude, .longitude, .placeName]) }
        // The wine-only fields keep their stored value on a beverage that is no
        // longer a wine: the server drops the whole details object anyway, and an
        // erasure computed from a form that hides the field would be a guess.
        if isWine {
            if appellation.isEmpty { emptied.insert(.appellation) }
            if classification.isEmpty { emptied.insert(.classification) }
            if varieties.isEmpty { emptied.insert(.grapeVarieties) }
            if drinkFrom.isEmpty { emptied.insert(.drinkFrom) }
            if drinkUntil.isEmpty { emptied.insert(.drinkUntil) }
        }
        return emptied
    }
}

extension WineEditForm {
    struct Fields {
        var name: String
        var beverageType: BeverageType = .wine
        var color: WineColor
        var subtype: BeverageSubtype? = nil
        var domain: String
        var vintage: String
        var appellation: String
        var region: String
        var country: String
        var classification: String
        var grapeVarieties: String
        var purchasePrice: String
        var purchaseDate: Date?
        var drinkFrom: String
        var drinkUntil: String
        var giftedBy: String
        var notes: String
        var alcoholContent: String = ""
        var place: TastingLocationDraft?
        var gift: GiftDraft?
        var tasting = TastingDraft()
        var recommendation = RecommendationDraft()
    }
}

#Preview {
    NavigationStack {
        WineEditForm(
            initial: .init(
                name: "Château Margaux",
                color: .red,
                domain: "Château Margaux",
                vintage: "2018",
                appellation: "Margaux",
                region: "Bordeaux",
                country: "France",
                classification: "Premier Grand Cru Classé",
                grapeVarieties: "Cabernet Sauvignon, Merlot",
                purchasePrice: "350",
                purchaseDate: Date(),
                drinkFrom: "2025",
                drinkUntil: "2045",
                giftedBy: "",
                notes: "Superbe millésime",
                alcoholContent: "13.5",
                tasting: .init(
                    rating: 4,
                    consumedDate: Date(),
                    contacts: ["Jean Dupont"],
                    tastingNotes: "Tanins souples"
                ),
                recommendation: .init(recommenderName: "Marie Martin", comment: "Un classique")
            ),
            onSave: { _ in },
            onCancel: {}
        )
    }
}
