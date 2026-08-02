import SwiftUI

struct JournalEventList: View {
    let events: [Event]
    var hasMore: Bool = false
    var loadMoreFailed: Bool = false
    var onEventTapped: (String) -> Void
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    private var groupedByDate: [(date: String, events: [Event])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: events) { event in
            formatter.string(from: event.date)
        }

        return grouped
            .map { (date: $0.key, events: $0.value) }
            .sorted { $0.events[0].date > $1.events[0].date }
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView("Aucun historique", systemImage: "clock", description: Text("L'historique apparaîtra ici"))
        } else {
            List {
                ForEach(groupedByDate, id: \.date) { group in
                    Section(group.date) {
                        ForEach(group.events) { event in
                            Button {
                                onEventTapped(event.wineId)
                            } label: {
                                JournalEventRow(
                                    isEntry: event.isEntry,
                                    position: event.position,
                                    memberName: event.memberName
                                ) {
                                    Text(event.title)
                                }
                            }
                            .tint(.primary)
                            .onAppear { onPrefetch(event.id) }
                        }
                    }
                }

                if hasMore {
                    LoadMoreRow(
                        failed: loadMoreFailed,
                        loadingLabel: "Chargement de plus d'événements",
                        onLoadMore: onLoadMore
                    )
                }
            }
        }
    }
}

extension JournalEventList {
    struct Event: Identifiable {
        let id: String
        let date: Date
        let isEntry: Bool
        let wineId: String
        let title: String
        let position: String
        /// The member behind the move, nil when it was you.
        var memberName: String? = nil
    }
}

#Preview("With events") {
    JournalEventList(
        events: [
            .init(id: "1-in", date: .now, isEntry: true, wineId: "1", title: "Chateau Margaux 2018", position: "A1"),
            .init(id: "2-in", date: .now, isEntry: true, wineId: "2", title: "Pouilly-Fume 2021", position: "B3"),
            .init(id: "3-out", date: .now.addingTimeInterval(-86400), isEntry: false, wineId: "3", title: "Cotes de Provence 2022", position: "C5", memberName: "Marie"),
        ],
        onEventTapped: { _ in }
    )
}

#Preview("Empty") {
    JournalEventList(events: [], onEventTapped: { _ in })
}
