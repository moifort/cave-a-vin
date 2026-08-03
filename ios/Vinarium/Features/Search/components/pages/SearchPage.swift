import SwiftUI

struct SearchPage: View {
    @Binding var filters: SearchFilters
    let sections: [WineListContent.Group]
    var hasActiveSearch: Bool
    var isLoading: Bool = false
    var errorMessage: String?
    var displayedCount: Int = 0
    var totalCount: Int = 0
    var onWineTapped: (String) -> Void

    /// The server caps the hits it returns: say so rather than let the list pass for
    /// the whole of what matched.
    private var isTruncated: Bool { totalCount > displayedCount && displayedCount > 0 }

    var body: some View {
        VStack(spacing: 0) {
            SearchFilterChips(filters: $filters)
                .padding(.vertical, 8)
            Divider()
            if isTruncated {
                Text("Les \(displayedCount) premiers résultats sur \(totalCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("search-results-summary")
                Divider()
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasActiveSearch {
            ContentUnavailableView(
                "Rechercher",
                systemImage: "magnifyingglass",
                description: Text("Un nom de vin, un producteur, un millésime ou une personne — ou affinez avec les filtres ci-dessus.")
            )
        } else if isLoading && sections.isEmpty {
            LoadingStateView(label: "Recherche…")
        } else if let errorMessage, sections.isEmpty {
            ContentUnavailableView(
                "Erreur",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if sections.isEmpty {
            ContentUnavailableView(
                "Aucun résultat",
                systemImage: "magnifyingglass",
                description: Text("Aucun vin ne correspond à cette recherche.")
            )
        } else {
            WineListContent(mode: .all, groups: sections, onWineTapped: onWineTapped)
        }
    }
}

#Preview("Suggestions") {
    @Previewable @State var filters = SearchFilters()
    SearchPage(filters: $filters, sections: [], hasActiveSearch: false, onWineTapped: { _ in })
}

#Preview("Loading") {
    @Previewable @State var filters = SearchFilters()
    SearchPage(
        filters: $filters, sections: [], hasActiveSearch: true, isLoading: true, onWineTapped: { _ in }
    )
}

#Preview("Results") {
    @Previewable @State var filters = SearchFilters()
    SearchPage(
        filters: $filters,
        sections: [
            .init(label: "En cave", items: [
                .init(id: "1", color: .red, name: "Château Margaux", subtitle: "2018 • Bordeaux", rating: 5, isFavorite: true, isInCellar: true),
            ]),
            .init(label: "Cadeaux", items: [
                .init(id: "2", color: .white, name: "Pouilly-Fumé", subtitle: "2021 • Offert par Marie D.", rating: 4, isFavorite: false),
            ]),
        ],
        hasActiveSearch: true,
        displayedCount: 2,
        totalCount: 2,
        onWineTapped: { _ in }
    )
}

#Preview("Truncated results") {
    @Previewable @State var filters = SearchFilters()
    SearchPage(
        filters: $filters,
        sections: [
            .init(label: "En cave", items: [
                .init(id: "1", color: .red, name: "Château Margaux", subtitle: "2018 • Bordeaux", rating: 5, isFavorite: true, isInCellar: true),
                .init(id: "2", color: .white, name: "Pouilly-Fumé", subtitle: "2021 • Loire", rating: 4, isFavorite: false, isInCellar: true),
            ]),
        ],
        hasActiveSearch: true,
        displayedCount: 20,
        totalCount: 47,
        onWineTapped: { _ in }
    )
}

#Preview("No result") {
    @Previewable @State var filters = SearchFilters()
    SearchPage(filters: $filters, sections: [], hasActiveSearch: true, onWineTapped: { _ in })
}
