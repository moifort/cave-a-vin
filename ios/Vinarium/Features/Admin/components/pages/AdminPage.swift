import SwiftUI

/// The Admin screen, pure and previewable: the four key figures as tiles, then the
/// month's breakdown (revenue, scans, tokens) and the refresh date.
struct AdminPage: View {
    let metrics: AdminMetrics?
    var isLoading = false
    var errorMessage: String?
    var onRetry: () async -> Void

    var body: some View {
        Group {
            if let metrics {
                content(metrics)
            } else if isLoading {
                LoadingStateView(label: "Chargement des métriques...")
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Métriques indisponibles", systemImage: "chart.bar.xaxis")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Réessayer") { Task { await onRetry() } }
                }
            } else {
                Color.clear
            }
        }
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ metrics: AdminMetrics) -> some View {
        List {
            Section {
                keyTiles(metrics)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("CA du mois") {
                LabeledContent("Net encaissé", value: euroOrUnavailable(metrics.revenueProceedsEur))
                LabeledContent("Brut", value: euroOrUnavailable(metrics.revenueGrossEur))
            }

            Section("Coûts du mois") {
                LabeledContent("Total", value: euro(metrics.totalCostEur))
                LabeledContent("Consommation IA", value: euro(metrics.aiCostEur))
                LabeledContent("Infra (GCP)", value: euroOrUnavailable(metrics.infraEur))
            }

            Section("Scans du mois") {
                LabeledContent("Scans Gemini", value: "\(metrics.scans)")
                LabeledContent("Servis par le cache", value: "\(metrics.cacheHits)")
            }

            Section("Tokens du mois") {
                tokenRows(title: "Vision", usage: metrics.vision)
                tokenRows(title: "Enrichissement", usage: metrics.enrichment)
            }

            Section {
            } footer: {
                Text(refreshFooter(metrics.refreshedAt))
            }
        }
    }

    private func keyTiles(_ metrics: AdminMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile(title: "Consommation IA", value: euro(metrics.aiCostEur), icon: "sparkles", tint: .purple)
            tile(title: "Infra", value: euroOrUnavailable(metrics.infraEur), icon: "server.rack", tint: .gray)
            tile(title: "Comptes", value: "\(metrics.totalUsers)", icon: "person.2.fill", tint: .blue)
            tile(title: "Premium", value: "\(metrics.premiumTotal)", icon: "crown.fill", tint: .orange)
        }
    }

    private func tile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func tokenRows(title: String, usage: AdminMetrics.TokenUsage) -> some View {
        LabeledContent("\(title), entrée", value: tokens(usage.promptTokens))
        LabeledContent("\(title), sortie", value: tokens(usage.outputTokens))
        LabeledContent("\(title), réflexion", value: tokens(usage.thinkingTokens))
    }

    private func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }

    private func euroOrUnavailable(_ value: Double?) -> String {
        value.map(euro) ?? "Indisponible"
    }

    private func tokens(_ count: Int) -> String {
        count.formatted(.number.grouping(.automatic))
    }

    private func refreshFooter(_ refreshedAt: Date?) -> String {
        guard let refreshedAt else {
            return "Comptes, abonnés et CA seront renseignés au premier passage du rafraîchissement quotidien."
        }
        let formatted = refreshedAt.formatted(date: .abbreviated, time: .shortened)
        return "Comptes, abonnés et CA actualisés le \(formatted). Les chiffres IA sont en direct."
    }
}

#Preview("Chargé") {
    NavigationStack {
        AdminPage(
            metrics: AdminMetrics(
                aiCostEur: 0.42,
                infraEur: 0.19,
                totalCostEur: 0.61,
                totalUsers: 42,
                premiumTotal: 5,
                premiumMonthly: 2,
                premiumYearly: 3,
                revenueProceedsEur: 12.4,
                revenueGrossEur: 17.9,
                scans: 37,
                cacheHits: 4,
                vision: .init(promptTokens: 96_200, outputTokens: 9_250, thinkingTokens: 55_500),
                enrichment: .init(promptTokens: 185_000, outputTokens: 7_400, thinkingTokens: 51_800),
                refreshedAt: Date()
            ),
            onRetry: {}
        )
    }
}

#Preview("Avant le premier rafraîchissement") {
    NavigationStack {
        AdminPage(
            metrics: AdminMetrics(
                aiCostEur: 0,
                infraEur: nil,
                totalCostEur: 0,
                totalUsers: 0,
                premiumTotal: 0,
                premiumMonthly: 0,
                premiumYearly: 0,
                revenueProceedsEur: nil,
                revenueGrossEur: nil,
                scans: 0,
                cacheHits: 0,
                vision: .init(promptTokens: 0, outputTokens: 0, thinkingTokens: 0),
                enrichment: .init(promptTokens: 0, outputTokens: 0, thinkingTokens: 0),
                refreshedAt: nil
            ),
            onRetry: {}
        )
    }
}

#Preview("Erreur") {
    NavigationStack {
        AdminPage(
            metrics: nil,
            errorMessage: "Réponse invalide du serveur",
            onRetry: {}
        )
    }
}
