import SwiftUI

/// Combinable filter chips offered above the results. Colors and types are
/// multi-select; in-cellar and consumed are exclusive (a single status).
struct SearchFilterChips: View {
    @Binding var filters: SearchFilters

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(WineColor.allCases) { color in
                    FilterChip(
                        label: color.label,
                        systemImage: "circle.fill",
                        tint: color.displayColor.color,
                        isOn: filters.colors.contains(color)
                    ) { toggle(color) }
                }

                FilterChip(
                    label: String(localized: "J'aime"), systemImage: "heart.fill",
                    isOn: filters.favorite
                ) {
                    filters.favorite.toggle()
                }
                FilterChip(label: String(localized: "En cave"), systemImage: "cabinet",
                           isOn: filters.status == .inCellar) {
                    filters.status = filters.status == .inCellar ? .all : .inCellar
                }
                FilterChip(label: String(localized: "Bu"), systemImage: "wineglass",
                           isOn: filters.status == .consumed) {
                    filters.status = filters.status == .consumed ? .all : .consumed
                }
                FilterChip(label: String(localized: "Cadeaux"), systemImage: "gift",
                           isOn: filters.gifted) {
                    filters.gifted.toggle()
                }

                ForEach(BeverageType.allCases) { type in
                    FilterChip(
                        label: type.label,
                        systemImage: type.icon,
                        isOn: filters.beverageTypes.contains(type)
                    ) { toggle(type) }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private func toggle(_ color: WineColor) {
        if filters.colors.contains(color) { filters.colors.remove(color) }
        else { filters.colors.insert(color) }
    }

    private func toggle(_ type: BeverageType) {
        if filters.beverageTypes.contains(type) { filters.beverageTypes.remove(type) }
        else { filters.beverageTypes.insert(type) }
    }
}

private struct FilterChip: View {
    let label: String
    let systemImage: String
    var tint: Color = .accentColor
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? tint.opacity(0.2) : Color(.secondarySystemFill),
                            in: Capsule())
                .foregroundStyle(isOn ? tint : Color.primary)
                .overlay(
                    Capsule().strokeBorder(isOn ? tint : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Chip states") {
    VStack(alignment: .leading, spacing: 12) {
        FilterChip(label: "Rouge", systemImage: "circle.fill", tint: .red, isOn: true) {}
        FilterChip(label: "Rouge", systemImage: "circle.fill", tint: .red, isOn: false) {}
        FilterChip(label: "En cave", systemImage: "cabinet", isOn: true) {}
        FilterChip(label: "En cave", systemImage: "cabinet", isOn: false) {}
    }
    .padding()
}

#Preview("All chips") {
    @Previewable @State var filters = SearchFilters()
    return VStack(alignment: .leading, spacing: 16) {
        SearchFilterChips(filters: $filters)
        Text("colors: \(filters.colors.map(\.label).joined(separator: ", "))")
            .font(.caption)
        Text("favorite: \(String(filters.favorite)) · status: \(filters.status.rawValue)")
            .font(.caption)
    }
}
