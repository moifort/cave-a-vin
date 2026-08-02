import Foundation

@MainActor @Observable
final class SearchViewModel {
    var query = "" { didSet { if oldValue != query { scheduleSearch() } } }
    var filters = SearchFilters() { didSet { if oldValue != filters { scheduleSearch() } } }

    private(set) var sections: [WineListContent.Group] = []
    private(set) var isLoading = false
    private(set) var error: String?

    /// Nothing is searched while there is neither text nor filter: the page then shows
    /// its suggestions rather than an empty list.
    var hasActiveSearch: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || filters.isActive
    }

    private var searchTask: Task<Void, Never>?
    // Stale-result token: Apollo fetches are not cancellable, so a response for an
    // earlier keystroke can arrive after a more recent one.
    private var generation = 0
    private let debounce = Duration.milliseconds(300)

    /// Cancels the in-flight search and schedules another one after the debounce. An
    /// empty query (no text, no filter) clears the results without a network call.
    func scheduleSearch() {
        searchTask?.cancel()
        generation += 1
        let requested = generation
        guard hasActiveSearch else {
            sections = []
            isLoading = false
            error = nil
            return
        }
        isLoading = true
        error = nil
        searchTask = Task {
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await run(generation: requested)
        }
    }

    private func run(generation requested: Int) async {
        let currentQuery = query
        let currentFilters = filters
        do {
            let results = try await SearchAPI.search(query: currentQuery, filters: currentFilters)
            guard requested == generation else { return } // a more recent keystroke landed
            sections = Self.sections(from: results.hits)
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            self.error = reportError(error)
        }
        guard requested == generation else { return }
        isLoading = false
    }

    // MARK: - Sectioning

    /// One section per kind of result. A wine matched on one of its own attributes
    /// (name, producer, region…) lands in its status section (in cellar / already
    /// drunk / others); a wine matched only through a person lands in that
    /// relationship's section (gifts / recommended / tasted with). Declaration order
    /// is display order.
    private enum Section: CaseIterable {
        case inCellar, consumed, other, gifted, recommended, tastedWith

        var label: String {
            switch self {
            case .inCellar: String(localized: "En cave")
            case .consumed: String(localized: "Déjà bus")
            case .other: String(localized: "Autres vins")
            case .gifted: String(localized: "Cadeaux")
            case .recommended: String(localized: "Conseillés")
            case .tastedWith: String(localized: "Dégustés avec")
            }
        }
    }

    private static func sections(from hits: [SearchHit]) -> [WineListContent.Group] {
        var buckets: [Section: [WineListContent.Item]] = [:]
        for hit in hits {
            buckets[section(for: hit), default: []].append(item(for: hit))
        }
        // Fixed section order; the server's relevance order is preserved inside each
        // section.
        return Section.allCases.compactMap { section in
            guard let items = buckets[section], !items.isEmpty else { return nil }
            return WineListContent.Group(label: section.label, items: items)
        }
    }

    private static func section(for hit: SearchHit) -> Section {
        let personFields: Set<SearchMatchedField> = [
            .giftedBy, .giftRecipient, .recommender, .tastingContact,
        ]
        let matchedOnlyPerson =
            !hit.matchedFields.isEmpty && hit.matchedFields.allSatisfy { personFields.contains($0) }
        if matchedOnlyPerson {
            if hit.matchedFields.contains(.giftedBy) || hit.matchedFields.contains(.giftRecipient) {
                return .gifted
            }
            if hit.matchedFields.contains(.recommender) { return .recommended }
            return .tastedWith
        }
        if hit.wine.isInCellar { return .inCellar }
        if hit.wine.consumedDate != nil { return .consumed }
        return .other
    }

    private static func item(for hit: SearchHit) -> WineListContent.Item {
        let wine = hit.wine
        return WineListContent.Item(
            id: wine.id,
            beverageType: wine.beverageType,
            color: wine.color,
            name: wine.name,
            subtitle: wine.listSubtitle,
            rating: wine.rating,
            isFavorite: wine.isFavorite,
            isInCellar: wine.isInCellar,
            ownerName: wine.ownerName
        )
    }
}
