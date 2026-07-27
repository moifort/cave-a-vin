import Foundation

enum WineListMode: String, CaseIterable, Identifiable {
    case all, favorites, gifted, recommended
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: String(localized: "Tous")
        case .favorites: String(localized: "Favoris")
        case .gifted: String(localized: "Offerts")
        case .recommended: String(localized: "Conseillés")
        }
    }
    var icon: String {
        switch self {
        case .all: "wineglass"
        case .favorites: "heart.fill"
        case .gifted: "gift"
        case .recommended: "lightbulb"
        }
    }

    var title: String {
        switch self {
        case .all: String(localized: "Mes Vins")
        case .favorites: String(localized: "Favoris")
        case .gifted: String(localized: "Offerts")
        case .recommended: String(localized: "Conseillés")
        }
    }

    var subtitle: String {
        switch self {
        case .all: String(localized: "Tous vos vins ajoutés")
        case .favorites: String(localized: "Vos coups de cœur")
        case .gifted: String(localized: "Vins qu'on vous a offerts")
        case .recommended: String(localized: "Vins recommandés par vos proches")
        }
    }

    /// Le Picker Statut n'a de sens que sur les modes non déjà filtrés par statut.
    var supportsStatusFilter: Bool {
        switch self {
        case .all, .favorites: true
        case .gifted, .recommended: false
        }
    }
}

enum WineSort: String, CaseIterable, Identifiable {
    case updatedAt, vintage, region, color, price, person
    var id: String { rawValue }
    var label: String {
        switch self {
        case .updatedAt: String(localized: "Date de modification")
        case .vintage: String(localized: "Millésime")
        case .region: String(localized: "Région")
        case .color: String(localized: "Couleur")
        case .price: String(localized: "Prix")
        case .person: String(localized: "Par personne")
        }
    }
    var icon: String {
        switch self {
        case .updatedAt: "clock"
        case .vintage: "calendar"
        case .region: "map"
        case .color: "paintpalette"
        case .price: "eurosign.circle"
        case .person: "person"
        }
    }

    /// « Par personne » n'a de sens que là où chaque vin porte une personne :
    /// qui l'a offert (Offerts) ou qui l'a conseillé (Conseillés).
    static func available(for mode: WineListMode) -> [WineSort] {
        allCases.filter { $0 != .person || mode == .gifted || mode == .recommended }
    }
}

enum WineStatusFilter: String, CaseIterable, Identifiable {
    case all, inCellar = "in-cellar", consumed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: String(localized: "Tous")
        case .inCellar: String(localized: "En cave")
        case .consumed: String(localized: "Consommés")
        }
    }
    var icon: String {
        switch self {
        case .all: "tray.full"
        case .inCellar: "cabinet"
        case .consumed: "wineglass"
        }
    }
}

private let wineMonthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.autoupdatingCurrent
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

@MainActor @Observable
final class WineListViewModel {
    /// Pages accumulées depuis le serveur, dans l'ordre de tri courant.
    private(set) var wines: [Wine] = []
    /// Démarre à true pour éviter un flash « Aucun vin » avant le premier load().
    var isLoading = true
    var isLoadingMore = false
    var hasMore = false
    /// Dernier loadMore en échec : la sentinelle devient un bouton « Réessayer »
    /// au lieu d'un spinner qui tournerait pour toujours sans nouvelle tentative.
    private(set) var loadMoreFailed = false
    var error: String?
    // Tout changement de vue/tri/filtre recharge la page 0 côté serveur.
    var sort: WineSort = .updatedAt { didSet { if oldValue != sort { scheduleReload() } } }
    var sortDescending = true { didSet { if oldValue != sortDescending { scheduleReload() } } }
    var statusFilter: WineStatusFilter = .all {
        didSet { if oldValue != statusFilter { scheduleReload() } }
    }
    var colorFilter: WineColor? { didSet { if oldValue != colorFilter { scheduleReload() } } }
    var beverageTypeFilter: BeverageType? {
        didSet { if oldValue != beverageTypeFilter { scheduleReload() } }
    }
    var mode: WineListMode = .all {
        didSet {
            guard oldValue != mode else { return }
            // Le tri « Par personne » n'existe pas hors Offerts/Conseillés : retomber
            // sur le tri par défaut. Son didSet planifie un reload redondant avec le
            // nôtre (même requête, l'un des deux aboutit) — bénin, pas de flash.
            if !WineSort.available(for: mode).contains(sort) { sort = .updatedAt }
            scheduleReload()
        }
    }

    private let pageSize = 15
    // Bien en dessous de pageSize, sinon la page suivante se chargerait dès
    // l'affichage de la première (chargement en chaîne involontaire).
    private let prefetchThreshold = 5
    private var reloadTask: Task<Void, Never>?
    // Jeton anti-résultats périmés : les fetch Apollo ne sont pas annulables, donc
    // une réponse d'une vue précédente peut arriver APRÈS celle de la vue courante.
    // Chaque scheduleReload invalide les réponses des générations antérieures.
    private var generation = 0

    private(set) var groupedWines: [(String, [Wine])] = []

    /// Recharge la page 0, en annulant un rechargement précédent encore en cours
    /// (changements de filtre rapides). Vide la liste et repasse en chargement pour
    /// que la vue affiche le loader et reparte de zéro. Appelé par les `didSet` et
    /// la navigation.
    func scheduleReload() {
        reloadTask?.cancel()
        generation += 1
        wines = []
        groupedWines = []
        hasMore = false
        isLoadingMore = false // les loadMore périmés sortent sans toucher cet état
        loadMoreFailed = false
        isLoading = true
        reloadTask = Task { await load() }
    }

    /// Charge la première page (au changement de vue/tri/filtre, à l'apparition,
    /// au pull-to-refresh et après une mutation).
    func load() async {
        let requested = generation
        isLoading = true
        error = nil
        do {
            let page = try await fetchPage(after: nil)
            guard requested == generation else { return } // réponse d'une vue périmée
            wines = page.items
            hasMore = page.hasMore
        } catch is CancellationError {
            // Rechargement annulé par un changement de filtre plus récent — on ignore.
            return
        } catch {
            guard requested == generation else { return }
            self.error = reportError(error)
        }
        rebuildPresentation()
        isLoading = false
    }

    /// Charge la page suivante et l'ajoute aux vins déjà chargés.
    func loadMore() async {
        guard hasMore, !isLoadingMore, let last = wines.last else { return }
        let requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await fetchPage(after: last.id)
            guard requested == generation else { return } // la vue a changé entre-temps
            wines.append(contentsOf: page.items)
            hasMore = page.hasMore
            rebuildPresentation()
        } catch is CancellationError {
            return
        } catch {
            guard requested == generation else { return }
            loadMoreFailed = true
            self.error = reportError(error)
        }
        isLoadingMore = false
    }

    /// Déclenche le chargement de la page suivante quand une ligne proche de la
    /// fin apparaît (infinite scroll).
    func prefetchIfNeeded(for wineId: String) {
        guard hasMore, !isLoadingMore else { return }
        guard let index = wines.firstIndex(where: { $0.id == wineId }) else { return }
        if wines.count - index <= prefetchThreshold {
            Task { await loadMore() }
        }
    }

    private func fetchPage(after: String?) async throws -> WinePage {
        try await WineAPI.list(
            mode: mode,
            sort: sort,
            sortDescending: sortDescending,
            statusFilter: statusFilter,
            color: colorFilter,
            beverageType: beverageTypeFilter,
            limit: pageSize,
            after: after
        )
    }

    // MARK: - Presentation: le serveur filtre (vue, statut, couleur, type) et
    // borne ; on regroupe seulement en sections localement.

    private func rebuildPresentation() {
        groupedWines = Self.buildGroupedWines(
            wines: wines,
            sort: sort,
            sortDescending: sortDescending,
            mode: mode
        )
    }

    /// Groupe sans personne quand le tri « Par personne » est actif.
    private static var unnamedPersonLabel: String { String(localized: "Sans nom") }

    private static func buildGroupedWines(
        wines: [Wine],
        sort: WineSort,
        sortDescending: Bool,
        mode: WineListMode
    ) -> [(String, [Wine])] {
        // Pre-sort so items inside each group follow the sort order too —
        // Dictionary(grouping:) preserves element order within groups.
        let sorted = wines.sorted {
            sortDescending ? sortValue($0, by: sort) > sortValue($1, by: sort)
                : sortValue($0, by: sort) < sortValue($1, by: sort)
        }

        let keyed = sorted.map { wine -> (sortKey: Double, label: String, wine: Wine) in
            switch sort {
            case .updatedAt:
                let calendar = Calendar.current
                let year = calendar.component(.year, from: wine.updatedAt)
                let month = calendar.component(.month, from: wine.updatedAt)
                let raw = wineMonthYearFormatter.string(from: wine.updatedAt)
                let label = raw.prefix(1).uppercased() + raw.dropFirst()
                return (Double(year * 100 + month), label, wine)
            case .vintage:
                let label = wine.vintage.map { "\($0)" } ?? String(localized: "Sans millésime")
                return (Double(wine.vintage ?? 0), label, wine)
            case .region:
                return (0, wine.region ?? String(localized: "Sans région"), wine)
            case .color:
                if let color = wine.color {
                    let order = WineColor.allCases.firstIndex(of: color) ?? 0
                    return (Double(order), color.label, wine)
                }
                // Boissons sans couleur (bière, spiritueux...) : groupées par type, après les vins
                let order = WineColor.allCases.count
                    + (BeverageType.allCases.firstIndex(of: wine.beverageType) ?? 0)
                return (Double(order), wine.beverageType.label, wine)
            case .price:
                let (order, label) = priceRange(wine.purchasePrice)
                return (Double(order), label, wine)
            case .person:
                // Offerts = la personne qui a offert la bouteille ; Conseillés = celle
                // qui l'a conseillée. (Tri absent des autres modes via available(for:).)
                let name = mode == .gifted ? wine.giftedBy : wine.recommendedBy
                return (0, name ?? unnamedPersonLabel, wine)
            }
        }

        let grouped = Dictionary(grouping: keyed, by: \.label)
        let result: [(key: String, value: [(sortKey: Double, label: String, wine: Wine)])]
        if sort == .region || sort == .person {
            // These groups have no numeric key — order them alphabetically (French-aware),
            // with the "no person" bucket pinned last whatever the direction.
            result = grouped.sorted { first, second in
                if sort == .person {
                    if first.key == unnamedPersonLabel { return false }
                    if second.key == unnamedPersonLabel { return true }
                }
                let ascending = first.key.localizedCompare(second.key) == .orderedAscending
                return sortDescending ? !ascending : ascending
            }
        } else {
            let representative = grouped.mapValues { entries in entries.first!.sortKey }
            result = grouped.sorted { first, second in
                let a = representative[first.key]!
                let b = representative[second.key]!
                return sortDescending ? a > b : a < b
            }
        }
        return result.map { ($0.key, $0.value.map(\.wine)) }
    }

    /// Per-wine comparable for intra-group ordering, aligned with the group keys.
    private static func sortValue(_ wine: Wine, by sort: WineSort) -> Double {
        switch sort {
        case .updatedAt: wine.updatedAt.timeIntervalSince1970
        case .vintage: Double(wine.vintage ?? 0)
        case .region: 0 // groups carry the ordering; keep server order inside
        // The full-subset paths (gifted/recommended) come back unsorted from the
        // server, so order inside each person's section explicitly.
        case .person: wine.updatedAt.timeIntervalSince1970
        case .color:
            Double(
                wine.color.map { WineColor.allCases.firstIndex(of: $0) ?? 0 }
                    ?? WineColor.allCases.count
                        + (BeverageType.allCases.firstIndex(of: wine.beverageType) ?? 0)
            )
        case .price: wine.purchasePrice ?? 0
        }
    }

    private static func priceRange(_ price: Double?) -> (order: Int, label: String) {
        guard let price else { return (999, String(localized: "Sans prix")) }
        // Thresholds stay in euros (matching the stored price); the labels show
        // the boundaries converted to the user's display currency.
        func bound(_ eur: Double) -> String { Money.formattedFromEur(eur, fractionLength: 0) }
        switch price {
        case ..<10: return (0, "< \(bound(10))")
        case ..<20: return (1, "\(bound(10))–\(bound(20))")
        case ..<50: return (2, "\(bound(20))–\(bound(50))")
        case ..<100: return (3, "\(bound(50))–\(bound(100))")
        default: return (4, "\(bound(100))+")
        }
    }
}
