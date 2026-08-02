import SwiftUI

struct WineListPage: View {
    @Binding var mode: WineListMode
    @Binding var sort: WineSort
    @Binding var sortDescending: Bool
    @Binding var statusFilter: WineStatusFilter
    @Binding var colorFilter: WineColor?
    @Binding var beverageTypeFilter: BeverageType?
    let groups: [WineListContent.Group]
    var hasMore: Bool = false
    var isLoading: Bool = false
    var loadMoreFailed: Bool = false
    var errorMessage: String?
    var onWineTapped: (String) -> Void
    var onRefresh: () async -> Void
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        WineListContent(
            mode: mode,
            groups: groups,
            hasMore: hasMore,
            isLoading: isLoading,
            loadMoreFailed: loadMoreFailed,
            errorMessage: errorMessage,
            onWineTapped: onWineTapped,
            onPrefetch: onPrefetch,
            onLoadMore: onLoadMore
        )
        .navigationTitle(mode.title)
        .navigationSubtitle(mode.subtitle)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await onRefresh() }
        .toolbar {
            ToolbarItemGroup {
                ForEach(WineListMode.allCases) { item in
                    Button {
                        mode = item
                    } label: {
                        Label(item.label, systemImage: item.icon)
                    }
                    .labelStyle(.iconOnly)
                    .tint(mode == item ? .accentColor : .primary)
                    .accessibilityIdentifier("winelist-mode-\(item.rawValue)")
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup {
                Menu {
                    Picker("Tri", selection: $sort) {
                        ForEach(WineSort.available(for: mode)) { sort in
                            Label(sort.label, systemImage: sort.icon).tag(sort)
                        }
                    }
                    Toggle(sortDescending ? "Décroissant" : "Croissant", isOn: $sortDescending)

                    if mode.supportsStatusFilter {
                        Divider()

                        Picker("Statut", selection: $statusFilter) {
                            ForEach(WineStatusFilter.allCases) { filter in
                                Label(filter.label, systemImage: filter.icon).tag(filter)
                            }
                        }
                    }

                    Divider()

                    Picker("Type", selection: $beverageTypeFilter) {
                        Label("Tous", systemImage: "circle.dashed").tag(BeverageType?.none)
                        ForEach(BeverageType.allCases) { type in
                            Label(type.label, systemImage: type.icon).tag(BeverageType?.some(type))
                        }
                    }

                    Picker("Couleur", selection: $colorFilter) {
                        Label("Toutes", systemImage: "circle.dashed").tag(WineColor?.none)
                        ForEach(WineColor.allCases) { color in
                            Label(color.label, systemImage: "circle.fill").tag(WineColor?.some(color))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .symbolVariant(
                            colorFilter != nil || beverageTypeFilter != nil
                                || (mode.supportsStatusFilter && statusFilter != .all)
                                ? .fill : .none
                        )
                }
                .accessibilityIdentifier("winelist-sort-menu")
            }
        }
        .searchToolbarButton()
    }
}

#Preview("With wines") {
    @Previewable @State var mode: WineListMode = .all
    @Previewable @State var sort: WineSort = .updatedAt
    @Previewable @State var sortDesc = true
    @Previewable @State var filter: WineStatusFilter = .all
    @Previewable @State var color: WineColor?
    @Previewable @State var beverageType: BeverageType?
    NavigationStack {
        WineListPage(
            mode: $mode,
            sort: $sort,
            sortDescending: $sortDesc,
            statusFilter: $filter,
            colorFilter: $color,
            beverageTypeFilter: $beverageType,
            groups: [
                .init(label: "Mars 2026", items: [
                    .init(id: "1", color: .red, name: "Château Margaux", subtitle: "2018 • Bordeaux", rating: 5, isFavorite: true),
                    .init(id: "2", color: .white, name: "Pouilly-Fumé", subtitle: "2021 • Loire", rating: 4, isFavorite: false),
                ]),
            ],
            onWineTapped: { _ in },
            onRefresh: {}
        )
    }
}

#Preview("Empty") {
    @Previewable @State var mode: WineListMode = .favorites
    @Previewable @State var sort: WineSort = .updatedAt
    @Previewable @State var sortDesc = true
    @Previewable @State var filter: WineStatusFilter = .all
    @Previewable @State var color: WineColor?
    @Previewable @State var beverageType: BeverageType?
    NavigationStack {
        WineListPage(
            mode: $mode,
            sort: $sort,
            sortDescending: $sortDesc,
            statusFilter: $filter,
            colorFilter: $color,
            beverageTypeFilter: $beverageType,
            groups: [],
            onWineTapped: { _ in },
            onRefresh: {}
        )
    }
}
