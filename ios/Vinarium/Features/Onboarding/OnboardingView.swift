import SwiftUI

/// First-launch setup wizard. Collects the user's first name and cellar dimensions,
/// then persists them via `completeOnboarding`. Calls `onCompleted` on success so
/// the auth gate can hand over to the main app without a network round-trip.
struct OnboardingView: View {
    var onCompleted: () -> Void

    @State private var viewModel = OnboardingViewModel()
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        NavigationStack {
            content
                .animation(.default, value: step)
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
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomePage(onNext: { go(.firstName) })
                .toolbar(.hidden, for: .navigationBar)
        case .firstName:
            FirstNamePage(
                firstName: $viewModel.firstName,
                onNext: { go(.preset) },
                onBack: { go(.welcome) }
            )
        case .preset:
            PresetChoicePage(
                presets: CellarPreset.all,
                onSelect: { viewModel.select($0) },
                onNext: { go(.dimensions) },
                onBack: { go(.firstName) }
            )
        case .dimensions:
            DimensionsPage(
                rows: $viewModel.rows,
                cols: $viewModel.cols,
                zones: $viewModel.zones,
                onNext: { go(.summary) },
                onBack: { go(.preset) }
            )
        case .summary:
            SummaryPage(
                firstName: viewModel.trimmedFirstName,
                rows: viewModel.rows,
                cols: viewModel.cols,
                zones: viewModel.zones,
                isSubmitting: viewModel.isSubmitting,
                onSubmit: submit,
                onBack: { go(.dimensions) }
            )
        }
    }

    private func go(_ next: OnboardingStep) {
        step = next
    }

    private func submit() {
        Task {
            if await viewModel.submit() { onCompleted() }
        }
    }
}

#Preview {
    OnboardingView(onCompleted: {})
}
