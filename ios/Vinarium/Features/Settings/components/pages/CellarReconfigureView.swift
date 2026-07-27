import SwiftUI

/// Reconfigure the cellar grid from Settings > Cave, reusing the onboarding
/// preset and dimensions pages. Presented as a sheet; calls `onReconfigured` with
/// the updated info on success so the settings page can refresh, then dismisses.
struct CellarReconfigureView: View {
    let initialRows: Int
    let initialCols: Int
    let initialZones: Int
    var onReconfigured: (CellarSettingsInfo) -> Void

    @State private var viewModel: CellarReconfigureViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        rows: Int,
        cols: Int,
        zones: Int,
        onReconfigured: @escaping (CellarSettingsInfo) -> Void
    ) {
        initialRows = rows
        initialCols = cols
        initialZones = zones
        self.onReconfigured = onReconfigured
        _viewModel = State(
            wrappedValue: CellarReconfigureViewModel(rows: rows, cols: cols, zones: zones)
        )
    }

    var body: some View {
        NavigationStack {
            content
                .animation(.default, value: viewModel.step)
        }
        .alert(
            "Une erreur est survenue",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
        .alert(
            "Impossible de réduire la cave",
            isPresented: Binding(
                get: { viewModel.blockedCount != nil },
                set: { if !$0 { viewModel.blockedCount = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(blockedMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .preset:
            PresetChoicePage(
                presets: CellarPreset.all,
                onSelect: { viewModel.select($0) },
                onNext: { viewModel.step = .dimensions },
                onBack: { dismiss() },
                backTitle: "Fermer",
                backSystemImage: "xmark",
                backRole: .cancel
            )
        case .dimensions:
            DimensionsPage(
                rows: $viewModel.rows,
                cols: $viewModel.cols,
                zones: $viewModel.zones,
                nextTitle: "Enregistrer",
                isBusy: viewModel.isSubmitting,
                onNext: save,
                onBack: { viewModel.step = .preset }
            )
        }
    }

    private var blockedMessage: String {
        let count = viewModel.blockedCount ?? 0
        let bottles =
            count == 1
            ? String(localized: "1 bouteille est placée")
            : String(localized: "\(count) bouteilles sont placées")
        return String(
            localized:
                "\(bottles) au-delà des nouvelles dimensions. Déplacez-les ou retirez-les d'abord."
        )
    }

    private func save() {
        Task {
            if let info = await viewModel.submit() {
                onReconfigured(info)
                dismiss()
            }
        }
    }
}

#Preview {
    CellarReconfigureView(rows: 6, cols: 8, zones: 1, onReconfigured: { _ in })
}
