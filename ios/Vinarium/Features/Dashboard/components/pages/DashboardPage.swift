import SwiftUI

struct DashboardPage: View {
    let content: Content
    var onStatsTapped: () -> Void
    var onWineTapped: (String) -> Void
    var onSettingsTapped: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DashboardStatsRow(stats: content.stats, onTapped: onStatsTapped)

                ReadyToDrinkSection(items: content.readyToDrink, onWineTapped: onWineTapped)

                FavoritesSection(items: content.favorites, onWineTapped: onWineTapped)

                JournalSection(events: content.events, onEventTapped: onWineTapped)
            }
            .padding()
        }
        .navigationTitle("Accueil")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIconButton(title: "Réglages", systemImage: "gearshape", action: onSettingsTapped)
                    .accessibilityIdentifier("dashboard-settings-button")
            }
        }
        .searchToolbarButton()
    }
}

extension DashboardPage {
    struct Content {
        let stats: DashboardStatsRow.Stats
        let readyToDrink: [ReadyToDrinkSection.Item]
        let favorites: [FavoritesSection.Item]
        let events: [JournalSection.Event]
    }
}

#Preview("With data") {
    NavigationStack {
        DashboardPage(
            content: .init(
                stats: .init(bottleCount: 42, capacity: 48, totalValue: 1850),
                readyToDrink: [
                    .init(id: "1", color: .red, name: "Château Margaux 2018", urgent: true, drinkUntil: 2026, position: "A3"),
                    .init(id: "2", color: .white, name: "Pouilly-Fumé 2021", urgent: false, drinkUntil: nil, position: "B1"),
                ],
                favorites: [
                    .init(id: "3", color: .red, name: "Romanée-Conti 2015", vintage: 2015, tastingDate: Date(), estimatedPrice: 3500, rating: 5),
                ],
                events: [
                    .init(isEntry: true, wineName: "Pétrus 2012", position: "C2", wineId: "5", date: Date()),
                ]
            ),
            onStatsTapped: {},
            onWineTapped: { _ in },
            onSettingsTapped: {}
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        DashboardPage(
            content: .init(
                stats: .init(bottleCount: 0, capacity: 48, totalValue: 0),
                readyToDrink: [],
                favorites: [],
                events: []
            ),
            onStatsTapped: {},
            onWineTapped: { _ in },
            onSettingsTapped: {}
        )
    }
}
