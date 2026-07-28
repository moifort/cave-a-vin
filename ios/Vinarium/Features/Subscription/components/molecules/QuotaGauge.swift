import SwiftUI

/// This month's scan consumption, as a counter and a bar. Primitive-first: it is
/// handed plain numbers, never the API's state, so it stays previewable and the
/// caller decides who deserves to see it.
///
/// Shown to free accounts only. A subscriber is metered too — an anti-abuse
/// ceiling — but showing it would contradict the unlimited scanning the very same
/// sheet is selling, and no real subscriber ever approaches it.
struct QuotaGauge: View {
    let used: Int
    let limit: Int
    let renewsOn: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Scans ce mois-ci")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(used) / \(limit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isExhausted ? .red : .secondary)
            }

            // Tinted red only once nothing is left: the colour carries that one
            // piece of information, and inherits the sheet's tint otherwise.
            ProgressView(value: Double(min(used, limit)), total: Double(max(limit, 1)))
                .tint(isExhausted ? .red : nil)

            if let renewsOn {
                Text("Renouvellement le \(renewsOn.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
        // Read as one thing: spelled out, "3 / 5" and the bar's percentage are
        // the same fact twice, and neither says what it counts.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(remaining) scans restants ce mois-ci"))
    }

    /// A limit lowered under an already-spent counter still reads as exhausted,
    /// which is what the server says too.
    private var isExhausted: Bool { used >= limit }

    /// Never negative, the way the server counts it.
    private var remaining: Int { max(0, limit - used) }
}

#Preview("Intact") {
    QuotaGauge(used: 0, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}

#Preview("Entamé") {
    QuotaGauge(used: 3, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}

#Preview("Épuisé") {
    QuotaGauge(used: 5, limit: 5, renewsOn: Date().addingTimeInterval(9 * 86_400))
        .padding()
}
