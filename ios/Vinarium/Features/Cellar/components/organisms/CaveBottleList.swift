import SwiftUI

struct CaveBottleList: View {
    let groups: [Group]
    var hasMore: Bool = false
    var loadMoreFailed: Bool = false
    var onBottleTapped: (String) -> Void
    var onRemoveRequested: (String) -> Void
    var onPrefetch: (String) -> Void = { _ in }
    var onLoadMore: () async -> Void = {}

    var body: some View {
        if groups.isEmpty {
            ContentUnavailableView("Cave vide", systemImage: "cabinet.fill", description: Text("Ajoutez des bouteilles via le scanner"))
        } else {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            Button {
                                onBottleTapped(item.id)
                            } label: {
                                BottleRow(beverageType: item.beverageType, color: item.color, position: item.position, ownerName: item.ownerName) {
                                    Text(item.title)
                                } subtitle: {
                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                    }
                                }
                            }
                            .tint(.primary)
                            .onAppear { onPrefetch(item.id) }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    onRemoveRequested(item.id)
                                } label: {
                                    Label("Sortir", systemImage: "arrow.up.circle")
                                }
                                .tint(.red)
                                .accessibilityIdentifier("cellar-remove-\(item.id)")
                            }
                        }
                    } header: {
                        Label("Rangée \(group.label)", systemImage: "cabinet")
                    }
                }

                if hasMore {
                    LoadMoreRow(
                        failed: loadMoreFailed,
                        loadingLabel: "Chargement de plus de bouteilles",
                        onLoadMore: onLoadMore
                    )
                }
            }
        }
    }
}

extension CaveBottleList {
    struct Group: Identifiable {
        let label: String
        let items: [Item]
        var id: String { label }
    }

    struct Item: Identifiable {
        let id: String
        var beverageType: BeverageType = .wine
        let color: WineColor?
        let title: String
        let subtitle: String?
        let position: String
        var ownerName: String?
    }
}

#Preview("With bottles") {
    CaveBottleList(

        groups: [
            .init(label: "A", items: [
                .init(id: "1", color: .red, title: "Chateau Margaux", subtitle: "2018", position: "A1"),
                .init(id: "2", color: .white, title: "Pouilly-Fume", subtitle: nil, position: "A2"),
            ]),
            .init(label: "B", items: [
                .init(id: "3", color: .rosé, title: "Cotes de Provence", subtitle: "2022", position: "B1", ownerName: "Marie"),
            ]),
        ],
        onBottleTapped: { _ in },
        onRemoveRequested: { _ in }
    )
}

#Preview("Empty") {
    CaveBottleList(

        groups: [],
        onBottleTapped: { _ in },
        onRemoveRequested: { _ in }
    )
}
