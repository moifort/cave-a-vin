import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var firstName: String?
    @State private var isLoadingFirstName = true
    @State private var loadError: String?
    @State private var signOutError: String?
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section {
                firstNameRow
                if let displayName = authSession.user?.displayName, !displayName.isEmpty {
                    LabeledInfoRow(title: "Nom", value: displayName, icon: "person.text.rectangle.fill")
                }
                if let email = authSession.user?.email, !email.isEmpty {
                    LabeledInfoRow(title: "Email", value: email, icon: "envelope.fill")
                }
                LabeledInfoRow(
                    title: "Identifiant",
                    value: shortUid,
                    icon: "key.fill"
                )
            } header: {
                Text("Compte")
            } footer: {
                if let loadError {
                    Text(loadError).foregroundStyle(.red)
                }
            }

            Section {
                SignOutButton(action: signOut)
            } footer: {
                if let signOutError {
                    Text(signOutError).foregroundStyle(.red)
                }
            }

            Section {
                // The dialog hangs off the button that opens it, so it pops out of
                // the row instead of floating mid-screen.
                DeleteAccountButton(isDeleting: isDeletingAccount) {
                    showDeleteConfirmation = true
                }
                .confirmationDialog(
                    "Supprimer définitivement le compte ?",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Supprimer mon compte", role: .destructive) {
                        Task { await deleteAccount() }
                    }
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text(
                        "Toutes les données seront effacées sans possibilité de récupération. Un abonnement Premium éventuel n'est pas résilié et reste à annuler dans l'App Store."
                    )
                }
            } footer: {
                if let deleteError {
                    Text(deleteError).foregroundStyle(.red)
                } else {
                    Text(
                        "Supprime définitivement le compte et toutes ses données. Cette action est irréversible. Un abonnement Premium n'est pas résilié : il reste à annuler dans les réglages de l'App Store."
                    )
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFirstName() }
    }

    @ViewBuilder
    private var firstNameRow: some View {
        if isLoadingFirstName {
            Label {
                LabeledContent("Prénom") { ProgressView() }
            } icon: {
                Image(systemName: "person.fill").foregroundStyle(.secondary)
            }
        } else if let firstName, !firstName.isEmpty {
            LabeledInfoRow(title: "Prénom", value: firstName, icon: "person.fill")
        }
    }

    private func loadFirstName() async {
        isLoadingFirstName = true
        loadError = nil
        do {
            firstName = try await OnboardingAPI.loadMe().firstName
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingFirstName = false
    }

    private var shortUid: String {
        guard let uid = authSession.user?.uid else { return "—" }
        return uid.prefix(8) + "…"
    }

    private func signOut() {
        do {
            try authSession.signOut()
        } catch {
            signOutError = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await SettingsAPI.deleteAccount()
            // The server has deleted the Firebase user; sign out locally to drop the
            // now-invalid session and route back to the login screen.
            try authSession.signOut()
        } catch {
            deleteError = error.localizedDescription
            isDeletingAccount = false
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
            .environment(AuthSession())
    }
}
