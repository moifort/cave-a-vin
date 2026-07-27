import SwiftUI

struct CellarPlacementView: View {
    let wineId: String
    let wineName: String
    var beverageType: BeverageType = .wine
    let wineColor: WineColor?
    let wineVintage: Int?
    var onCancel: () -> Void = {}
    let onPlaced: (String) -> Void

    @State private var bottles: [CellarBottle] = []
    @State private var suggestedRow: String?
    @State private var suggestedCol: Int?
    @State private var rows = 6
    @State private var cols = 8
    @State private var isLoading = true
    @State private var error: String?
    @State private var isPlacing = false

    private var suggestedPosition: String? {
        guard let row = suggestedRow, let col = suggestedCol else { return nil }
        return "\(row)\(col)"
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(label: "Chargement de la cave...")
            } else if let error {
                ContentUnavailableView("Erreur", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                CellarPlacementPage(
                    wineName: wineName,
                    beverageType: beverageType,
                    wineColor: wineColor,
                    wineVintage: wineVintage,
                    groups: availableGroups,
                    suggestedPosition: suggestedPosition,
                    isPlacing: isPlacing,
                    onCancel: onCancel,
                    onPlaceConfirmed: { position in placeWine(position: position) }
                )
            }
        }
        .task {
            await loadData()
        }
    }

    private var availableGroups: [CellarPlacementPage.Group] {
        let occupied = Set(bottles.map { $0.position })
        return (0..<rows).compactMap { rowIdx in
            let rowLetter = String(UnicodeScalar(65 + rowIdx)!)
            let free: [CellarPlacementPage.Position] = (1...cols).compactMap { col in
                let label = "\(rowLetter)\(col)"
                guard !occupied.contains(label) else { return nil }
                return .init(label: label)
            }
            guard !free.isEmpty else { return nil }
            return .init(row: rowLetter, positions: free)
        }
    }

    private func loadData() async {
        do {
            async let bottlesData = CellarAPI.getAllBottles()
            async let suggestion = CellarAPI.suggest()
            async let gridInfo = CellarAPI.info()
            let (b, s, g) = try await (bottlesData, suggestion, gridInfo)
            bottles = b
            suggestedRow = s.row
            suggestedCol = s.col
            rows = g.rows
            cols = g.cols
            isLoading = false
        } catch {
            self.error = reportError(error)
            isLoading = false
        }
    }

    private func placeWine(position: String) {
        let rowStr = String(position.prefix(1))
        let col = Int(position.dropFirst()) ?? 0
        isPlacing = true

        Task {
            do {
                try await CellarAPI.place(wineId: wineId, rowLabel: rowStr, colLabel: col)
                onPlaced(position)
            } catch {
                self.error = reportError(error)
            }
            isPlacing = false
        }
    }
}

#Preview {
    NavigationStack {
        CellarPlacementView(
            wineId: "1",
            wineName: "Château Margaux",
            wineColor: .red,
            wineVintage: 2018,
            onPlaced: { _ in }
        )
    }
}
