import SwiftUI

struct WineDetailContent: View {
    let content: Content
    var onRemoveRequested: () -> Void = {}
    var onEditLocation: () -> Void = {}

    var body: some View {
        List {
            WineDetailHeader(
                beverageType: content.beverageType,
                color: content.color,
                name: content.name,
                subtitle: headerSubtitle,
                producerLabel: content.beverageType.producerLabel,
                domain: content.domain,
                vintage: content.vintage,
                ownerName: content.ownerName,
                cellarPosition: currentCellarPosition
            )

            if content.beverageType == .wine {
                WineOriginSection(
                    appellation: content.appellation,
                    region: content.region,
                    country: content.country,
                    classification: content.classification
                )
            }

            LocationSection(
                placeName: content.placeName,
                latitude: content.latitude,
                longitude: content.longitude,
                onTap: onEditLocation
            )

            WineDetailsSection(
                alcoholContent: content.alcoholContent,
                purchasePrice: content.purchasePrice,
                purchaseDate: content.purchaseDate,
                grapeVarieties: content.grapeVarieties
            )

            if content.beverageType == .wine {
                WineAgingSection(drinkFrom: content.drinkFrom, drinkUntil: content.drinkUntil)
            }

            if let cellar = content.cellar {
                WineCellarSection(
                    position: cellar.position,
                    dateIn: cellar.dateIn,
                    dateOut: cellar.dateOut,
                    isInCellar: cellar.isInCellar,
                    onRemoveRequested: onRemoveRequested
                )
            }

            if let consumption = content.consumption {
                WineConsumptionSection(
                    consumedDate: consumption.consumedDate,
                    rating: consumption.rating,
                    tastingNotes: consumption.tastingNotes,
                    contacts: consumption.contacts
                )
            }

            if let gift = content.gift {
                WineGiftSection(giftedDate: gift.giftedDate, recipientName: gift.recipientName)
            }

            if let giftedBy = content.giftedBy {
                Section("Offert par") {
                    Label {
                        Text(giftedBy)
                    } icon: {
                        Image(systemName: "gift")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let recommendation = content.recommendation {
                WineRecommendationSection(
                    recommenderName: recommendation.recommenderName,
                    comment: recommendation.comment
                )
            }

            if let notes = content.notes, !notes.isEmpty {
                Section("Notes") {
                    Label {
                        Text(notes)
                    } icon: {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// The slot only makes sense while the bottle is still stored; once it is out,
    /// the position belongs to the cellar history and stays in the cellar section.
    private var currentCellarPosition: String? {
        guard let cellar = content.cellar, cellar.isInCellar else { return nil }
        return cellar.position
    }

    private var headerSubtitle: String {
        // Uniquement le sous-type (« Porto », « Blonde »). À défaut de sous-type,
        // on affiche la couleur pour un vin, le type pour les autres boissons.
        // La maison et le millésime restent affichés plus bas (LabeledInfoRow) — inutile de les répéter ici.
        if let subtypeLabel = content.subtype?.label(for: content.beverageType) {
            return subtypeLabel
        }
        let fallback = content.beverageType == .wine
            ? content.color?.label
            : content.beverageType.label
        return fallback ?? ""
    }
}

extension WineDetailContent {
    struct Content {
        var beverageType: BeverageType = .wine
        let color: WineColor?
        var subtype: BeverageSubtype? = nil
        let name: String
        let domain: String?
        let vintage: Int?
        let appellation: String?
        let region: String?
        let country: String?
        let classification: String?
        let placeName: String?
        let latitude: Double?
        let longitude: Double?
        let alcoholContent: Double?
        let purchasePrice: Double?
        let purchaseDate: String?
        let grapeVarieties: [String]
        let drinkFrom: Int?
        let drinkUntil: Int?
        let giftedBy: String?
        let notes: String?
        let cellar: CellarSection?
        let consumption: ConsumptionSection?
        let gift: GiftSection?
        let recommendation: RecommendationSection?
        var ownerName: String? = nil
    }

    struct CellarSection {
        let position: String
        let dateIn: String
        let dateOut: String?
        let isInCellar: Bool
    }

    struct ConsumptionSection {
        let consumedDate: String?
        let rating: Int?
        let tastingNotes: String?
        let contacts: [String]?
    }

    struct GiftSection {
        let giftedDate: String
        let recipientName: String?
    }

    struct RecommendationSection {
        let recommenderName: String?
        let comment: String?
    }
}

#Preview("En cave") {
    WineDetailContent(
        content: .init(
            color: .red,
            name: "Château Margaux",
            domain: "Château Margaux",
            vintage: 2018,
            appellation: "Margaux",
            region: "Bordeaux",
            country: "France",
            classification: "Premier Grand Cru Classé",
            placeName: nil,
            latitude: nil,
            longitude: nil,
            alcoholContent: 13.5,
            purchasePrice: 350,
            purchaseDate: nil,
            grapeVarieties: ["Cabernet Sauvignon", "Merlot"],
            drinkFrom: 2025,
            drinkUntil: 2045,
            giftedBy: nil,
            notes: "Superbe millésime",
            cellar: .init(position: "A3", dateIn: "01/01/2024", dateOut: nil, isInCellar: true),
            consumption: nil,
            gift: nil,
            recommendation: nil
        ),
        onRemoveRequested: {}
    )
}

#Preview("Consommé") {
    WineDetailContent(
        content: .init(
            color: .white,
            name: "Pouilly-Fumé",
            domain: nil,
            vintage: 2022,
            appellation: "Pouilly-Fumé",
            region: "Loire",
            country: "France",
            classification: nil,
            placeName: nil,
            latitude: nil,
            longitude: nil,
            alcoholContent: nil,
            purchasePrice: nil,
            purchaseDate: nil,
            grapeVarieties: ["Sauvignon Blanc"],
            drinkFrom: nil,
            drinkUntil: nil,
            giftedBy: nil,
            notes: nil,
            cellar: .init(position: "B1", dateIn: "15/03/2024", dateOut: "14/04/2024", isInCellar: false),
            consumption: .init(consumedDate: "14/04/2024", rating: 4, tastingNotes: "Très frais, belle minéralité", contacts: ["Jean", "Marie"]),
            gift: nil,
            recommendation: nil
        ),
        onRemoveRequested: {}
    )
}
