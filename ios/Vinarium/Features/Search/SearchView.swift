import SwiftUI

/// Full-screen global search, presented as an overlay from the toolbar magnifier.
/// Cancelling closes the overlay and goes back to the originating page.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @State private var selectedWineId: String?
    @State private var searchActive = false
    // The field only closes after it has been opened: this avoids a premature dismiss
    // on the very first render, before activation.
    @State private var didActivate = false

    var body: some View {
        NavigationStack {
            SearchPage(
                filters: $viewModel.filters,
                sections: viewModel.sections,
                hasActiveSearch: viewModel.hasActiveSearch,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.error,
                onWineTapped: { selectedWineId = $0 }
            )
            .navigationTitle("Recherche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                    .accessibilityIdentifier("search-close-button")
                }
                if viewModel.isLoading {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProgressView()
                    }
                }
            }
            .searchable(
                text: $viewModel.query,
                isPresented: $searchActive,
                prompt: "Vin, producteur, personne…"
            )
            .sheet(item: Binding(
                get: { selectedWineId.map { WineIdWrapper(id: $0) } },
                set: { selectedWineId = $0?.id }
            )) { wrapper in
                WineDetailView(
                    wineId: wrapper.id,
                    // After a mutation in the detail view, run the search again so the
                    // change shows up (favorite, cellar, deletion).
                    onRemoved: { viewModel.scheduleSearch() },
                    onUpdated: { viewModel.scheduleSearch() }
                )
            }
        }
        .onAppear { searchActive = true }
        .onChange(of: searchActive) { _, active in
            if active {
                didActivate = true
            } else if didActivate && selectedWineId == nil {
                // The field deactivates on the native Cancel, so close the overlay.
                // Guard: do not close when the deactivation comes from presenting the
                // detail sheet (coming back to the search is expected there).
                dismiss()
            }
        }
    }
}

#Preview {
    // No query, no filter: the coordinator shows the suggestions of its page
    // without calling the server.
    SearchView()
}
