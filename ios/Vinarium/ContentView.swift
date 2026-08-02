import SwiftUI

enum TabSelection: Int, CaseIterable, Identifiable {
    case home, cellar, wines, scan
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .home: String(localized: "Accueil")
        case .cellar: String(localized: "Cave")
        case .wines: String(localized: "Vins")
        case .scan: String(localized: "Scanner")
        }
    }
}

struct ContentView: View {
    /// A pending invitation from a universal link, presented once the app is ready.
    @Binding var joinRequest: HouseholdJoinRequest?

    /// Admin only: the metrics banner pinned above every tab. Absent (and never
    /// fetched) for everyone else.
    @Environment(\.isAdmin) private var isAdmin
    @Environment(\.scenePhase) private var scenePhase
    @State private var adminViewModel = AdminViewModel()
    @State private var showAdminSheet = false

    @State private var selectedTab: TabSelection = .home
    /// The last real content tab, restored when the scan cover is dismissed.
    @State private var lastContentTab: TabSelection = .home
    @State private var showScanner = false
    @State private var cellarRefreshTrigger = UUID()
    @State private var wineListRefreshTrigger = UUID()
    @State private var showFavorites = false
    @State private var showRecommended = false
    @State private var searchPresenter = SearchPresenter()

    /// The trailing "Scanner" entry must stay detached from the content tabs.
    /// iOS 26 separates the `.search` role; iOS 27 folded `.search` back into the
    /// main tab row and introduced `.prominent` for a trailing-separated tab.
    /// Pick the role that detaches on the running OS, guarding `.prominent`
    /// behind the SDK that defines it (Swift 6.4 / Xcode 27) so the app still
    /// builds with Xcode 26.
    private var scanTabRole: TabRole {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return .prominent
        }
        #endif
        return .search
    }

    var body: some View {
        // The admin banner is stacked ABOVE the TabView, not injected as a top
        // safe-area inset: an inset leaves each tab's navigation bar drawing at
        // the true top, so its title and toolbar buttons end up clipped behind
        // the banner. Stacking gives the TabView the room below the banner and
        // its nav bars lay out cleanly.
        if isAdmin {
            VStack(spacing: 0) {
                AdminBanner(
                    aiCost: bannerEuro(adminViewModel.metrics?.aiCostEur),
                    infra: bannerEuro(adminViewModel.metrics?.infraEur),
                    users: bannerCount(adminViewModel.metrics?.totalUsers),
                    premium: bannerCount(adminViewModel.metrics?.premiumTotal),
                    isLoading: adminViewModel.isLoading,
                    onTap: { showAdminSheet = true }
                )
                tabs
            }
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .home) {
                DashboardView(selectedTab: $selectedTab)
            } label: {
                tabLabel(for: .home)
            }
            .accessibilityIdentifier("tab-home")
            Tab(value: .cellar) {
                CellarView(refreshTrigger: cellarRefreshTrigger)
            } label: {
                tabLabel(for: .cellar)
            }
            .accessibilityIdentifier("tab-cellar")
            Tab(value: .wines) {
                WineListView(
                    showFavorites: $showFavorites,
                    showRecommended: $showRecommended,
                    refreshTrigger: wineListRefreshTrigger
                )
            } label: {
                tabLabel(for: .wines)
            }
            .accessibilityIdentifier("tab-wines")
            Tab(value: .scan, role: scanTabRole) {
                Color.clear
            } label: {
                tabLabel(for: .scan)
            }
            .accessibilityIdentifier("tab-scan")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            if isAdmin { await adminViewModel.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isAdmin {
                Task { await adminViewModel.load() }
            }
        }
        .sheet(isPresented: $showAdminSheet) {
            NavigationStack {
                AdminView(viewModel: adminViewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                                showAdminSheet = false
                            }
                        }
                    }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .scan {
                showScanner = true
            } else {
                lastContentTab = newValue
            }
        }
        .environment(searchPresenter)
        .fullScreenCover(isPresented: $searchPresenter.isPresented) {
            SearchView()
        }
        .fullScreenCover(isPresented: $showScanner, onDismiss: restoreContentTab) {
            ScanView { result in
                showScanner = false
                switch result {
                case .addedToCellar:
                    selectedTab = .cellar
                    cellarRefreshTrigger = UUID()
                case .addedToFavorites:
                    selectedTab = .wines
                    showFavorites = true
                case .addedToRecommendations:
                    selectedTab = .wines
                    showRecommended = true
                case .added:
                    selectedTab = .wines
                }
            }
        }
        .sheet(item: $joinRequest) { request in
            JoinHouseholdSheet(code: request.code) {
                // The guest now shares the cave: refresh both the grid and the wine
                // list so the joined household's bottles appear without a manual
                // reload (the list and search now span the shared cellar too).
                cellarRefreshTrigger = UUID()
                wineListRefreshTrigger = UUID()
            }
        }
    }

    /// Tab bar label with a pinned Dynamic Type size, so the symbols keep a
    /// fixed size whatever the user's text size setting. Accueil and Cave use
    /// native symbols; Vins and Scanner use the custom wine-themed symbols,
    /// always in their filled form.
    @ViewBuilder
    private func tabLabel(for tab: TabSelection) -> some View {
        Group {
            switch tab {
            case .home:
                Label(tab.label, systemImage: "house")
            case .cellar:
                Label(tab.label, systemImage: "square.grid.3x3")
            case .wines:
                Label(tab.label, image: "tab.wines.fill")
            case .scan:
                Label(tab.label, image: "tab.scan.fill")
            }
        }
        .dynamicTypeSize(.large)
    }

    /// After the scan cover closes, leave the empty scan tab and return to the
    /// content tab the user came from (unless a successful scan already routed
    /// the selection elsewhere).
    private func restoreContentTab() {
        if selectedTab == .scan { selectedTab = lastContentTab }
    }

    /// One amount of the banner: an ellipsis while nothing is loaded, the value otherwise.
    private func bannerEuro(_ value: Double?) -> String {
        value.map(euroString) ?? "…"
    }

    private func bannerCount(_ value: Int?) -> String {
        value.map(String.init) ?? "…"
    }

    /// The banner's infra figure tells loading (an ellipsis) apart from a measure that
    /// is still unavailable (a dash, when the billing export is not wired up).
    private var bannerInfra: String {
        guard let metrics = adminViewModel.metrics else { return "…" }
        return metrics.infraEur.map(euroString) ?? "—"
    }

    private func euroString(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }
}

#Preview {
    ContentView(joinRequest: .constant(nil))
}
