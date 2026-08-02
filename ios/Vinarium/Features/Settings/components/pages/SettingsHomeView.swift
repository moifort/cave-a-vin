import SwiftUI

struct SettingsHomeView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.isAdmin) private var isAdmin
    @Environment(\.dismiss) private var dismiss
    @State private var premiumShown = false
    @State private var feedbackShown = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "person.crop.circle.fill",
                            title: "Profil",
                            subtitle: profileSubtitle,
                            tint: .blue
                        )
                    }
                }

                Section {
                    Button {
                        premiumShown = true
                    } label: {
                        SettingsRow(
                            icon: "sparkles",
                            title: subscriptions.isPremium == true ? "Vinarium Premium" : "Découvrir Premium",
                            subtitle: subscriptionSubtitle,
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Application") {
                    NavigationLink {
                        ChangelogListView()
                    } label: {
                        SettingsRow(
                            icon: "doc.text.fill",
                            title: "Version & changelog",
                            subtitle: "v\(appVersion) (\(buildNumber))",
                            tint: .indigo
                        )
                    }
                    Button {
                        feedbackShown = true
                    } label: {
                        SettingsRow(
                            icon: "envelope.fill",
                            title: "Nous écrire",
                            subtitle: "Signaler un problème ou proposer une idée",
                            tint: .pink
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Cave") {
                    NavigationLink {
                        CellarInfoSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "square.grid.3x3.fill",
                            title: "Informations",
                            tint: .brown
                        )
                    }
                    NavigationLink {
                        SharingSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "person.2.fill",
                            title: "Partage",
                            tint: .purple
                        )
                    }
                }

                Section("Données") {
                    NavigationLink {
                        ImportExportSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "square.and.arrow.up.fill",
                            title: "Importer / Exporter",
                            tint: .teal
                        )
                    }
                }

                // Second admin entry point, next to the banner. Absent for every
                // other account.
                if isAdmin {
                    Section {
                        NavigationLink {
                            AdminView()
                        } label: {
                            SettingsRow(
                                icon: "chart.bar.fill",
                                title: "Admin",
                                subtitle: "Coûts, revenus et comptes du mois",
                                tint: .red
                            )
                        }
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $premiumShown) {
                PremiumSheet(trigger: .discover)
            }
            .sheet(isPresented: $feedbackShown) {
                FeedbackSheet()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private var profileSubtitle: String? {
        authSession.user?.displayName ?? authSession.user?.email
    }

    /// What the subscription gives today: the number of scans left on a free account,
    /// the renewal date for a subscriber.
    private var subscriptionSubtitle: String? {
        guard let quota = subscriptions.quota else { return nil }
        if quota.isPremium {
            return String(localized: "Scans illimités")
        }
        return quota.remaining == 0
            ? String(localized: "Aucun scan restant ce mois-ci")
            : String(localized: "\(quota.remaining) scans restants ce mois-ci")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}

#Preview {
    SettingsHomeView()
        .environment(AuthSession())
}
