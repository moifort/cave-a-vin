import SwiftUI

struct SummaryPage: View {
    let firstName: String
    let rows: Int
    let cols: Int
    let zones: Int
    let isSubmitting: Bool
    var onSubmit: () -> Void
    var onBack: () -> Void

    private var capacity: Int { rows * cols }

    /// What finishing the wizard grants. Mirrors `WELCOME_SCANS` on the server,
    /// which is the source of truth: the grant happens there, this only announces
    /// it, so the two move together.
    private let welcomeScans = 20

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("\(capacity)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text(capacity > 1 ? "bouteilles au total" : "bouteille au total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section("Récapitulatif") {
                    LabeledContent {
                        Text(firstName)
                    } label: {
                        Label("Prénom", systemImage: "person.fill")
                    }
                    LabeledContent {
                        Text("\(rows)")
                    } label: {
                        Label("Rangées", systemImage: "square.grid.3x3")
                    }
                    LabeledContent {
                        Text("\(cols)")
                    } label: {
                        Label("Emplacements par rangée", systemImage: "rectangle.split.3x1")
                    }
                    LabeledContent {
                        Text("\(zones)")
                    } label: {
                        Label("Zones de température", systemImage: "thermometer.medium")
                    }
                    LabeledContent {
                        Text("\(capacity) bouteilles").fontWeight(.semibold)
                    } label: {
                        Label("Capacité totale", systemImage: "square.stack.3d.up.fill")
                    }
                }

                Section {
                    Label("\(welcomeScans) scans offerts", systemImage: "gift")
                        .foregroundStyle(.tint)
                } footer: {
                    Text(
                        "Photographiez une étiquette et la fiche se remplit toute seule. De quoi saisir la cave sans rien taper."
                    )
                }
            }

            Button(action: onSubmit) {
                Text("Terminer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitting)
            .padding()
            .accessibilityIdentifier("onboarding-finish")
        }
        .navigationTitle("Résumé")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIconButton(title: "Retour", systemImage: "chevron.left", action: onBack)
                    .disabled(isSubmitting)
            }
        }
        .overlay {
            if isSubmitting {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView("Enregistrement…")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SummaryPage(
            firstName: "Thibaut",
            rows: 12,
            cols: 6,
            zones: 2,
            isSubmitting: false,
            onSubmit: {},
            onBack: {}
        )
    }
}
