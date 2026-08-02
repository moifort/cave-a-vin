import Foundation

enum CellarDisplayMode: String, CaseIterable, Identifiable {
    case cave = "Cave"
    case journal = "Journal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cave: "cabinet"
        case .journal: "clock"
        }
    }

    var label: String {
        switch self {
        case .cave: String(localized: "Cave")
        case .journal: String(localized: "Journal")
        }
    }

    var title: String {
        switch self {
        case .cave: String(localized: "Ma Cave")
        case .journal: String(localized: "Journal")
        }
    }

    var subtitle: String {
        switch self {
        case .cave: String(localized: "Vos bouteilles en cave")
        case .journal: String(localized: "Historique des entrées et sorties")
        }
    }
}

@MainActor @Observable
final class CellarGridViewModel {
    var bottles: [CellarBottle] = []
    var bottlesHasMore = false
    var isLoadingMoreBottles = false
    private(set) var bottlesLoadMoreFailed = false
    var history: [HistoryEvent] = []
    var historyHasMore = false
    var isLoadingMoreHistory = false
    private(set) var historyLoadMoreFailed = false
    var displayMode: CellarDisplayMode = .cave
    var isLoading = false
    var error: String?

    private let pageSize = 15
    private let prefetchThreshold = 5
    // Stale-result token: a load() (pull-to-refresh, return from a scan) invalidates
    // the loadMore calls still in flight, otherwise their late response would append
    // duplicates to the freshly reloaded lists.
    private var generation = 0

    var groupedRows: [CellarRowGroup] {
        Dictionary(grouping: bottles, by: \.rowLabel)
            .sorted(by: { $0.key < $1.key })
            .map { row, items in
                CellarRowGroup(
                    row: row,
                    items: items.sorted(by: { $0.colLabel < $1.colLabel }).map {
                        CellarRowItem(
                            id: $0.wine.id,
                            name: $0.wine.name,
                            beverageType: $0.wine.beverageType,
                            color: $0.wine.color,
                            vintage: $0.wine.vintage,
                            position: $0.position,
                            ownerName: $0.ownerName
                        )
                    }
                )
            }
    }

    func load() async {
        generation += 1
        let requested = generation
        isLoadingMoreBottles = false
        isLoadingMoreHistory = false
        bottlesLoadMoreFailed = false
        historyLoadMoreFailed = false
        isLoading = true
        error = nil
        do {
            async let bottlesData = CellarAPI.getBottles(limit: pageSize, after: nil)
            async let historyData = CellarAPI.getHistory(limit: pageSize, offset: 0)
            let (b, h) = try await (bottlesData, historyData)
            guard requested == generation else { return } // a more recent reload took over
            bottles = b.bottles
            bottlesHasMore = b.hasMore
            history = h.events
            historyHasMore = h.hasMore
        } catch {
            guard requested == generation else { return }
            self.error = reportError(error)
        }
        isLoading = false
    }

    /// Loads the next page of bottles and appends it to the grid.
    func loadMoreBottles() async {
        guard bottlesHasMore, !isLoadingMoreBottles, let last = bottles.last else { return }
        let requested = generation
        isLoadingMoreBottles = true
        bottlesLoadMoreFailed = false
        do {
            let page = try await CellarAPI.getBottles(limit: pageSize, after: last.wineId)
            guard requested == generation else { return } // the list was reloaded in the meantime
            bottles.append(contentsOf: page.bottles)
            bottlesHasMore = page.hasMore
        } catch {
            guard requested == generation else { return }
            bottlesLoadMoreFailed = true
            self.error = reportError(error)
        }
        isLoadingMoreBottles = false
    }

    /// Triggers the next load when a bottle close to the end appears.
    func prefetchBottlesIfNeeded(for wineId: String) {
        guard bottlesHasMore, !isLoadingMoreBottles else { return }
        guard let index = bottles.firstIndex(where: { $0.wineId == wineId }) else { return }
        if bottles.count - index <= prefetchThreshold {
            Task { await loadMoreBottles() }
        }
    }

    /// Loads the next page of the journal and appends it to the history.
    func loadMoreHistory() async {
        guard historyHasMore, !isLoadingMoreHistory else { return }
        let requested = generation
        isLoadingMoreHistory = true
        historyLoadMoreFailed = false
        do {
            let page = try await CellarAPI.getHistory(limit: pageSize, offset: history.count)
            guard requested == generation else { return } // the list was reloaded in the meantime
            history.append(contentsOf: page.events)
            historyHasMore = page.hasMore
        } catch {
            guard requested == generation else { return }
            historyLoadMoreFailed = true
            self.error = reportError(error)
        }
        isLoadingMoreHistory = false
    }

    /// Triggers the next load when an event close to the end appears.
    func prefetchHistoryIfNeeded(for eventId: String) {
        guard historyHasMore, !isLoadingMoreHistory else { return }
        guard let index = history.firstIndex(where: { $0.id == eventId }) else { return }
        if history.count - index <= prefetchThreshold {
            Task { await loadMoreHistory() }
        }
    }
}
