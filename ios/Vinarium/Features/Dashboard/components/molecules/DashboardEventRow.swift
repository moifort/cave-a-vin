import SwiftUI

struct DashboardEventRow: View {
    let isEntry: Bool
    let wineName: String
    let label: LocalizedStringKey
    let position: String
    /// The member behind the move, nil when it was you.
    var memberName: String? = nil

    var body: some View {
        // Same recipe as the other rows: icon aligned to the top, full-width text
        // column aligned to the left, name truncated with an ellipsis.
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEntry ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(isEntry ? .green : .red)
                .font(.title3)
                .accessibilityLabel(isEntry ? "Entr\u{00E9}e" : "Sortie")

            VStack(alignment: .leading, spacing: 2) {
                Text(wineName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let memberName {
                    MemberBadge(name: memberName)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PositionBadge(position: position)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

#Preview {
    VStack(spacing: 0) {
        DashboardEventRow(
            isEntry: true,
            wineName: "Ch\u{00E2}teau Margaux 2018",
            label: "Derni\u{00E8}re entr\u{00E9}e",
            position: "A3"
        )
        DashboardEventRow(
            isEntry: false,
            wineName: "Pouilly-Fum\u{00E9} 2021",
            label: "Derni\u{00E8}re sortie",
            position: "B1",
            memberName: "Marie"
        )
    }
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
    .padding()
}
