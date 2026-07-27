import Foundation

@MainActor @Observable
final class SearchViewModel {
    var query = "" { didSet { if oldValue != query { scheduleSearch() } } }
    var filters = SearchFilters() { didSet { if oldValue != filters { scheduleSearch() } } }

    private(set) var sections: [WineListContent.Group] = []
    private(set) var isLoading = false
    private(set) var error: String?

    /// Rien n'est cherché tant qu'il n'y a ni texte ni filtre : la page montre
    /// alors ses suggestions plutôt qu'une liste vide.
    var hasActiveSearch: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || filters.isActive
    }

    private var searchTask: Task<Void, Never>?
    // Jeton anti-résultats périmés : les fetch Apollo ne sont pas annulables, donc
    // une réponse d'une frappe précédente peut arriver après une plus récente.
    private var generation = 0
    private let debounce = Duration.milliseconds(300)

    /// Annule la recherche en vol et en reprogramme une après le debounce. Une
    /// requête vide (ni texte ni filtre) vide les résultats sans appel réseau.
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
            guard requested == generation else { return } // frappe plus récente arrivée
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

    // MARK: - Sectionnement

    /// Une section par nature de résultat. Un vin matché sur un de ses attributs
    /// (nom, producteur, région…) va dans sa section de statut (En cave / Déjà bus /
    /// Autres) ; un vin matché uniquement par une personne va dans la section de
    /// cette relation (Cadeaux / Conseillés / Dégustés avec). L'ordre de
    /// déclaration est l'ordre d'affichage.
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
        // Ordre fixe des sections ; l'ordre de pertinence du serveur est préservé
        // à l'intérieur de chaque section.
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
