import SwiftUI

struct CellarPage: View {
    @Binding var displayMode: CellarDisplayMode
    let groups: [CaveBottleList.Group]
    let events: [JournalEventList.Event]
    var bottlesHasMore: Bool = false
    var bottlesLoadMoreFailed: Bool = false
    var historyHasMore: Bool = false
    var historyLoadMoreFailed: Bool = false
    var onBottleTapped: (String) -> Void
    var onRemoveRequested: (String) -> Void
    var onEventTapped: (String) -> Void
    var onRefresh: () async -> Void
    var onBottlesPrefetch: (String) -> Void = { _ in }
    var onBottlesLoadMore: () async -> Void = {}
    var onHistoryPrefetch: (String) -> Void = { _ in }
    var onHistoryLoadMore: () async -> Void = {}

    var body: some View {
        Group {
            switch displayMode {
            case .cave:
                CaveBottleList(
                    groups: groups,
                    hasMore: bottlesHasMore,
                    loadMoreFailed: bottlesLoadMoreFailed,
                    onBottleTapped: onBottleTapped,
                    onRemoveRequested: onRemoveRequested,
                    onPrefetch: onBottlesPrefetch,
                    onLoadMore: onBottlesLoadMore
                )
            case .journal:
                JournalEventList(
                    events: events,
                    hasMore: historyHasMore,
                    loadMoreFailed: historyLoadMoreFailed,
                    onEventTapped: onEventTapped,
                    onPrefetch: onHistoryPrefetch,
                    onLoadMore: onHistoryLoadMore
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ForEach(CellarDisplayMode.allCases) { mode in
                    Button {
                        displayMode = mode
                    } label: {
                        Label(mode.label, systemImage: mode.icon)
                    }
                    .labelStyle(.iconOnly)
                    .tint(displayMode == mode ? .accentColor : .primary)
                    .accessibilityIdentifier("cellar-mode-\(mode.rawValue)")
                }
            }
            // Detaches the magnifier from the mode toggles into its own capsule.
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        .searchToolbarButton()
        .navigationTitle(displayMode.title)
        .navigationSubtitle(displayMode.subtitle)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await onRefresh() }
    }
}

#Preview("Cellar with bottles") {
    @Previewable @State var mode: CellarDisplayMode = .cave
    NavigationStack {
        CellarPage(
            displayMode: $mode,
            groups: [
                .init(label: "A", items: [
                    .init(id: "1", color: .red, title: "Château Margaux", subtitle: "2018", position: "A1"),
                    .init(id: "2", color: .white, title: "Pouilly-Fumé", subtitle: nil, position: "A2"),
                ]),
                .init(label: "B", items: [
                    .init(id: "3", color: .rosé, title: "Côtes de Provence", subtitle: "2022", position: "B1"),
                ]),
            ],
            events: [],
            onBottleTapped: { _ in },
            onRemoveRequested: { _ in },
            onEventTapped: { _ in },
            onRefresh: {}
        )
    }
}

#Preview("Journal") {
    @Previewable @State var mode: CellarDisplayMode = .journal
    NavigationStack {
        CellarPage(
            displayMode: $mode,
            groups: [],
            events: [
                .init(id: "1-in", date: .now, isEntry: true, wineId: "1", title: "Château Margaux 2018", position: "A1"),
                .init(id: "2-out", date: .now.addingTimeInterval(-86400), isEntry: false, wineId: "2", title: "Pouilly-Fumé 2021", position: "B3"),
            ],
            onBottleTapped: { _ in },
            onRemoveRequested: { _ in },
            onEventTapped: { _ in },
            onRefresh: {}
        )
    }
}

#Preview("Empty cellar") {
    @Previewable @State var mode: CellarDisplayMode = .cave
    NavigationStack {
        CellarPage(
            displayMode: $mode,
            groups: [],
            events: [],
            onBottleTapped: { _ in },
            onRemoveRequested: { _ in },
            onEventTapped: { _ in },
            onRefresh: {}
        )
    }
}
