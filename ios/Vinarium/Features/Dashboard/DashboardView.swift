import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: TabSelection

    @State private var viewModel = DashboardViewModel()
    @State private var selectedWineId: String?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let data = viewModel.data {
                    DashboardPage(
                        content: Self.map(data),
                        onStatsTapped: { selectedTab = .cellar },
                        onWineTapped: { selectedWineId = $0 },
                        onSettingsTapped: { showSettings = true }
                    )
                } else if let error = viewModel.error {
                    ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    LoadingStateView()
                }
            }
            .refreshable { await viewModel.load() }
            .task {
                await viewModel.load()
            }
            // The view stays alive inside the TabView: without this, coming back to the
            // home tab after a scan or a mutation would show stale stats.
            .onChange(of: selectedTab) {
                if selectedTab == .home {
                    Task { await viewModel.load() }
                }
            }
            .sheet(item: Binding(
                get: { selectedWineId.map { WineIdWrapper(id: $0) } },
                set: { selectedWineId = $0?.id }
            )) { wrapper in
                WineDetailView(
                    wineId: wrapper.id,
                    onRemoved: { Task { await viewModel.load() } },
                    onUpdated: { Task { await viewModel.load() } }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsHomeView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .vinariumDataDidReload)) { _ in
                Task { await viewModel.load() }
            }
        }
    }

    private static func map(_ data: DashboardData) -> DashboardPage.Content {
        .init(
            stats: .init(bottleCount: data.bottleCount, capacity: data.capacity, totalValue: data.totalValue),
            readyToDrink: data.readyToDrink.map { wine in
                .init(id: wine.id, beverageType: wine.beverageType, color: wine.color, name: wine.name, urgent: wine.urgent, drinkUntil: wine.drinkUntil, position: wine.position)
            },
            favorites: data.favorites.map { favorite in
                .init(id: favorite.id, beverageType: favorite.beverageType, color: favorite.color, name: favorite.name, vintage: favorite.vintage, tastingDate: favorite.tastingDate, estimatedPrice: favorite.estimatedPrice, rating: favorite.rating)
            },
            events: data.history.map { event in
                .init(isEntry: event.isEntry, wineName: event.wineName, position: event.position, wineId: event.wineId, date: event.date, memberName: event.memberName)
            }
        )
    }
}

#Preview {
    @Previewable @State var selectedTab: TabSelection = .home
    DashboardView(selectedTab: $selectedTab)
}
