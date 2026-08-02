import SwiftUI

/// The admin banner pinned above the whole app: the four key figures on one line, a
/// discreet loading state while the request runs, and a tap that opens the full Admin
/// screen.
struct AdminBanner: View {
    let aiCost: String
    let infra: String
    let users: String
    let premium: String
    var isLoading = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                figure(label: "IA", value: aiCost)
                separator
                figure(label: "Infra", value: infra)
                separator
                figure(label: "Comptes", value: users)
                separator
                figure(label: "Premium", value: premium)
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("admin-banner")
    }

    private var separator: some View {
        Text("·")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func figure(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.caption2)
        .lineLimit(1)
    }
}

#Preview("Chargé") {
    VStack(spacing: 0) {
        AdminBanner(
            aiCost: "0,42 €",
            infra: "8,12 €",
            users: "42",
            premium: "5",
            onTap: {}
        )
        Spacer()
    }
}

#Preview("Chargement") {
    VStack(spacing: 0) {
        AdminBanner(
            aiCost: "…",
            infra: "…",
            users: "…",
            premium: "…",
            isLoading: true,
            onTap: {}
        )
        Spacer()
    }
}
