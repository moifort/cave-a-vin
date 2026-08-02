import SwiftUI

/// Drives the opening of the global search. Shared through the environment so the
/// magnifier of any page presents the same overlay at the root level.
@MainActor @Observable
final class SearchPresenter {
    var isPresented = false

    func present() { isPresented = true }
}

private struct SearchToolbarButton: View {
    // Optional: absent from page previews, present in the app through ContentView.
    @Environment(SearchPresenter.self) private var presenter: SearchPresenter?

    var body: some View {
        Button { presenter?.present() } label: {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityIdentifier("search-button")
        .accessibilityLabel(Text("Rechercher"))
    }
}

extension View {
    /// Adds the global search magnifier at the head of the toolbar. Apply it to the
    /// root page of every tab that should give access to the search.
    func searchToolbarButton() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) { SearchToolbarButton() }
        }
    }
}

#Preview("With a presenter") {
    @Previewable @State var presenter = SearchPresenter()
    NavigationStack {
        Text(presenter.isPresented ? "Recherche demandée" : "Contenu")
            .navigationTitle("Ma Cave")
            .searchToolbarButton()
    }
    .environment(presenter)
}

#Preview("Without a presenter") {
    // The environment value is absent from page previews: the button renders and
    // simply does nothing when tapped.
    NavigationStack {
        Text("Contenu")
            .navigationTitle("Ma Cave")
            .searchToolbarButton()
    }
}
