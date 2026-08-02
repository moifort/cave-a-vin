import Foundation

/// The monthly figures the admin surfaces display: measured costs (Gemini tokens,
/// GCP bill), App Store revenue and account counts.
struct AdminMetrics {
    struct TokenUsage {
        let promptTokens: Int
        let outputTokens: Int
        let thinkingTokens: Int
    }

    let aiCostEur: Double
    /// The project's measured GCP bill, nil while the billing export is not configured
    /// or has not answered yet. No fixed line item: the Apple Developer subscription,
    /// shared across several projects, is deliberately left out.
    let infraEur: Double?
    let totalCostEur: Double
    let totalUsers: Int
    let premiumTotal: Int
    let premiumMonthly: Int
    let premiumYearly: Int
    /// Net proceeds (what Apple pays out), nil while the App Store Connect key has not answered.
    let revenueProceedsEur: Double?
    let revenueGrossEur: Double?
    let scans: Int
    let cacheHits: Int
    let vision: TokenUsage
    let enrichment: TokenUsage
    /// Last run of the daily refresh, nil before its first execution.
    let refreshedAt: Date?
}
