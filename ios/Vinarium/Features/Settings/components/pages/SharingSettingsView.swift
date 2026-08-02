import SwiftUI

/// Coordinator for household sharing: loads the current household, then either
/// offers to create/join one, or manages members and invitation codes. The name
/// attached to invitations and joins comes from the account (`me.firstName`).
struct SharingSettingsView: View {
    @State private var household: Household?
    @State private var firstName: String?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var memberToRemove: HouseholdMember?
    @State private var codeToRevoke: String?
    @State private var actionError = ErrorPresenter()

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView()
            } else {
                Form {
                    if let household {
                        inHousehold(household)
                    } else {
                        noHousehold
                    }
                    if let loadError {
                        Text(loadError).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Partage")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if actionError.isRunning {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .disabled(actionError.isRunning)
        .errorAlert(actionError)
        .confirmationDialog(
            "Retirer ce membre ?",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Retirer \(member.displayName)", role: .destructive) {
                Task { await removeMember(userId: member.userId) }
            }
        } message: { member in
            Text("\(member.displayName) n'aura plus accès à la cave commune.")
        }
        .confirmationDialog(
            "Révoquer ce code ?",
            isPresented: Binding(
                get: { codeToRevoke != nil },
                set: { if !$0 { codeToRevoke = nil } }
            ),
            titleVisibility: .visible,
            presenting: codeToRevoke
        ) { code in
            Button("Révoquer", role: .destructive) {
                Task { await revoke(code: code) }
            }
        } message: { _ in
            Text("Le code ne pourra plus être utilisé pour rejoindre le foyer.")
        }
    }

    // MARK: - No household

    @ViewBuilder
    private var noHousehold: some View {
        Section {
            Text("Partagez votre cave avec les personnes de votre foyer. Chacun garde sa bibliothèque, ses notes et son journal ; seules les bouteilles en cave sont communes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Section("Inviter quelqu'un") {
            Button {
                Task { await generateInvite() }
            } label: {
                Text("Générer un code d'invitation")
            }
        }
        Section("Rejoindre un foyer") {
            JoinHouseholdForm(isWorking: actionError.isRunning) { code in
                Task { await join(code: code) }
            }
        }
    }

    // MARK: - In a household

    @ViewBuilder
    private func inHousehold(_ household: Household) -> some View {
        Section("Membres du foyer") {
            HouseholdMemberList(
                items: household.members.map {
                    .init(userId: $0.userId, name: $0.displayName, isOwner: $0.isOwner, isMe: $0.isMe)
                },
                canRemove: household.iAmOwner,
                onRemove: { userId in
                    memberToRemove = household.members.first { $0.userId == userId }
                }
            )
        }

        Section("Invitations") {
            if household.invitations.isEmpty {
                Text("Aucun code actif").foregroundStyle(.secondary)
            }
            ForEach(household.invitations) { invite in
                InviteCodeCard(code: invite.code, expiresAt: invite.expiresAt) {
                    codeToRevoke = invite.code
                }
            }
        }

        Section {
            Button {
                Task { await generateInvite() }
            } label: {
                Label("Générer un nouveau code", systemImage: "plus")
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        // Fetch both concurrently. The household drives the screen, so only its
        // failure surfaces an error; the first name is best-effort (an existing member
        // already carries a name, and the fallback covers a missing one).
        async let me = OnboardingAPI.loadMe()
        do {
            household = try await HouseholdAPI.myHousehold()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        firstName = (try? await me)?.firstName
        isLoading = false
    }

    private func generateInvite() async {
        let name = currentName
        await actionError.run {
            _ = try await HouseholdAPI.createInvitation(displayName: name)
            household = try await HouseholdAPI.myHousehold()
        }
    }

    private func join(code: String) async {
        let name = currentName
        await actionError.run {
            household = try await HouseholdAPI.join(code: code, displayName: name)
        }
    }

    private func removeMember(userId: String) async {
        await actionError.run {
            household = try await HouseholdAPI.removeMember(userId: userId)
        }
    }

    private func revoke(code: String) async {
        await actionError.run {
            try await HouseholdAPI.revokeInvitation(code: code)
            household = try await HouseholdAPI.myHousehold()
        }
    }

    /// The name to attach to a new invitation or join: the viewer's existing name
    /// within the household if they are already a member, otherwise their account
    /// first name (`me.firstName`, guaranteed by onboarding).
    private var currentName: String {
        if let me = household?.members.first(where: { $0.isMe }) { return me.displayName }
        let trimmed = (firstName ?? "").trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Moi" : trimmed
    }
}

#Preview {
    NavigationStack {
        SharingSettingsView()
    }
}
