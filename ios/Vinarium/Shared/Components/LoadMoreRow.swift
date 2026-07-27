import SwiftUI

/// Ligne sentinelle de pagination : déclenche le chargement de la page suivante
/// à son apparition, et devient un bouton « Réessayer » si la page a échoué —
/// sinon le spinner tournerait pour toujours sans nouvelle tentative.
struct LoadMoreRow: View {
    let failed: Bool
    let loadingLabel: LocalizedStringKey
    let onLoadMore: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            if failed {
                Button {
                    Task { await onLoadMore() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("load-more-retry")
            } else {
                ProgressView()
                    .accessibilityLabel(loadingLabel)
                    .task { await onLoadMore() }
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}

#Preview("Chargement") {
    List {
        LoadMoreRow(failed: false, loadingLabel: "Chargement de plus de vins", onLoadMore: {})
    }
}

#Preview("Échec") {
    List {
        LoadMoreRow(failed: true, loadingLabel: "Chargement de plus de vins", onLoadMore: {})
    }
}
