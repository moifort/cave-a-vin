import SwiftUI

struct JournalSection: View {
    let events: [Event]
    var onEventTapped: (String) -> Void

    var body: some View {
        let lastEntry = events.first { $0.isEntry }
        let lastExit = events.first { !$0.isEntry }

        VStack(alignment: .leading, spacing: 12) {
            Label("Journal", systemImage: "book")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if events.isEmpty {
                Text("Aucun événement récent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray6))
                    .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    if let entry = lastEntry {
                        Button { onEventTapped(entry.wineId) } label: {
                            DashboardEventRow(
                                isEntry: true,
                                wineName: entry.wineName,
                                label: "Dernière entrée le \(entry.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))",
                                position: entry.position,
                                memberName: entry.memberName
                            )
                        }
                        .tint(.primary)
                    }
                    if let exit = lastExit {
                        Button { onEventTapped(exit.wineId) } label: {
                            DashboardEventRow(
                                isEntry: false,
                                wineName: exit.wineName,
                                label: "Dernière sortie le \(exit.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))",
                                position: exit.position,
                                memberName: exit.memberName
                            )
                        }
                        .tint(.primary)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }
}

extension JournalSection {
    struct Event {
        let isEntry: Bool
        let wineName: String
        let position: String
        let wineId: String
        let date: Date
        /// The member behind the move, nil when it was you.
        var memberName: String? = nil
    }
}

#Preview("With events") {
    JournalSection(
        events: [
            .init(isEntry: true, wineName: "Château Margaux 2018", position: "A3", wineId: "1", date: Date()),
            .init(isEntry: false, wineName: "Pouilly-Fumé 2021", position: "B1", wineId: "2", date: Date(), memberName: "Marie"),
        ],
        onEventTapped: { _ in }
    )
    .padding()
}

#Preview("Empty") {
    JournalSection(events: [], onEventTapped: { _ in })
        .padding()
}
