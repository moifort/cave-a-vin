import SwiftUI

struct WineDetailPage: View {
    let content: WineDetailContent.Content
    var onRemoveRequested: () -> Void = {}
    var onEditLocation: () -> Void = {}
    var onEditTasting: (() -> Void)? = nil
    var onRefresh: () async -> Void = {}

    var body: some View {
        WineDetailContent(
            content: content,
            onRemoveRequested: onRemoveRequested,
            onEditLocation: onEditLocation,
            onEditTasting: onEditTasting
        )
        .refreshable { await onRefresh() }
    }
}

#Preview("In cellar") {
    NavigationStack {
        WineDetailPage(
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
            )
        )
    }
}
