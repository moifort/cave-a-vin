import SwiftUI

struct ReadyToDrinkSection: View {
    let items: [Item]
    var onWineTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pr\u{00EA}t \u{00E0} d\u{00E9}guster", systemImage: "wineglass")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if items.isEmpty {
                Text("Aucun vin prêt à déguster")
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
                            // Same recipe as the other rows: badge aligned to the top.
                            HStack(alignment: .top, spacing: 10) {
                                BeverageBadge(beverageType: item.beverageType, color: item.color)
                                Text(item.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if item.urgent, let year = item.drinkUntil {
                                    Text("Avant \(String(year))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.orange, in: .capsule)
                                }
                                Spacer()
                                PositionBadge(position: item.position)
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
    }
}

extension ReadyToDrinkSection {
    struct Item: Identifiable {
        let id: String
        var beverageType: BeverageType = .wine
        let color: WineColor?
        let name: String
        let urgent: Bool
        let drinkUntil: Int?
        let position: String
    }
}

#Preview("Avec vins") {
    ReadyToDrinkSection(
        items: [
            .init(id: "1", color: .red, name: "Ch\u{00E2}teau Margaux 2018", urgent: true, drinkUntil: 2026, position: "A3"),
            .init(id: "2", color: .white, name: "Pouilly-Fum\u{00E9} 2021", urgent: false, drinkUntil: nil, position: "B1"),
        ],
        onWineTapped: { _ in }
    )
    .padding()
}

#Preview("Vide") {
    ReadyToDrinkSection(items: [], onWineTapped: { _ in })
        .padding()
}
