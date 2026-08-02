import SwiftUI

/// Coordinator for the Admin screen: it owns (or receives) the ViewModel, loads on
/// appear and delegates all rendering to `AdminPage`. The banner passes its own
/// ViewModel so the sheet shows the figures already loaded; the settings row lets the
/// coordinator create its own.
struct AdminView: View {
    @State private var viewModel: AdminViewModel

    init(viewModel: AdminViewModel = AdminViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        AdminPage(
            metrics: viewModel.metrics,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onRetry: { await viewModel.load() }
        )
        .task {
            if viewModel.metrics == nil { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
    }
}

#Preview {
    NavigationStack {
        AdminView()
    }
}
