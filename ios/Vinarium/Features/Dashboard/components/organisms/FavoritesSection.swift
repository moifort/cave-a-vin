import SwiftUI

struct FavoritesSection: View {
    let items: [Item]
    var onWineTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Mes favoris", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if items.isEmpty {
                Text("Aucun favori")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray6))
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            onWineTapped(item.id)
                        } label: {
                            // Same recipe as the other rows: badge aligned to the top,
                            // full-width text column aligned to the left.
                            HStack(alignment: .top, spacing: 10) {
                                BeverageBadge(beverageType: item.beverageType, color: item.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        if let vintage = item.vintage {
                                            Text(verbatim: "\(vintage)")
                                        }
                                        if item.vintage != nil, item.tastingDate != nil {
                                            Text("\u{2022}")
                                        }
                                        if let date = item.tastingDate {
                                            Text("Consomm\u{00E9} le \(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if let rating = item.rating {
                                    StarRatingView(rating: rating)
                                } else if let price = item.estimatedPrice {
                                    Text(Money.formattedFromEur(price, fractionLength: 0))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                        }
                        .tint(.primary)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .accessibilityIdentifier("dashboard-favorites-section")
    }
}

extension FavoritesSection {
    struct Item: Identifiable {
        let id: String
        var beverageType: BeverageType = .wine
        let color: WineColor?
        let name: String
        let vintage: Int?
        let tastingDate: Date?
        let estimatedPrice: Double?
        var rating: Int? = nil
    }
}

#Preview("Avec favoris") {
    FavoritesSection(
        items: [
            .init(id: "1", color: .red, name: "Ch\u{00E2}teau Margaux 2018", vintage: 2018, tastingDate: Date(), estimatedPrice: 120, rating: 5),
            .init(id: "2", color: .white, name: "Pouilly-Fum\u{00E9} 2021", vintage: 2021, tastingDate: nil, estimatedPrice: nil, rating: 3),
        ],
        onWineTapped: { _ in }
    )
    .padding()
}

#Preview("Vide") {
    FavoritesSection(items: [], onWineTapped: { _ in })
        .padding()
}
