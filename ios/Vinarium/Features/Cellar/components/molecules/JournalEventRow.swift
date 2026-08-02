import SwiftUI

struct JournalEventRow<Title: View>: View {
    let isEntry: Bool
    let position: String
    let memberName: String?
    let title: Title

    init(isEntry: Bool, position: String, memberName: String? = nil, @ViewBuilder title: () -> Title) {
        self.isEntry = isEntry
        self.position = position
        self.memberName = memberName
        self.title = title()
    }

    var body: some View {
        // Same recipe as the other rows: icon aligned to the top, full-width text
        // column aligned to the left, name truncated with an ellipsis.
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEntry ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(isEntry ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(isEntry ? "Entrée" : "Sortie")
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
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        JournalEventRow(isEntry: true, position: "A1") {
            Text("Chateau Margaux 2018")
        }
        JournalEventRow(isEntry: false, position: "C5") {
            Text("Cotes de Provence 2022")
        }
        JournalEventRow(isEntry: true, position: "B2", memberName: "Marie") {
            Text("Sancerre 2021")
        }
    }
}
