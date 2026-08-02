import SwiftUI

struct BottleMovePage: View {
    let wineName: String
    var wineBeverageType: BeverageType = .wine
    let wineColor: WineColor?
    let wineVintage: Int?
    let currentPosition: String
    let groups: [Group]
    let isMoving: Bool
    var onCancel: () -> Void = {}
    var onMoveConfirmed: (_ row: String, _ col: Int) -> Void

    @State private var pending: Pending?

    var body: some View {
        VStack(spacing: 0) {
            wineHeader

            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.cells) { cell in
                            cellRow(cell)
                        }
                    } header: {
                        Label("Rangée \(group.row)", systemImage: "cabinet")
                    }
                }
            }
            .alert(
                pending?.occupant == nil
                    ? "Déplacer en \(pending?.position ?? "") ?"
                    : "Échanger avec \(pending?.occupant?.name ?? "") (\(pending?.position ?? "")) ?",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                )
            ) {
                Button("Confirmer") {
                    if let target = pending {
                        onMoveConfirmed(target.row, target.col)
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
        }
        .navigationTitle("Déplacer")
        .navigationBarTitleDisplayMode(.inline)
        // Scrim and spinner while the write runs; cancelling is disabled so the page
        // cannot close in the middle of the mutation.
        .overlay {
            if isMoving {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { onCancel() }
                    .disabled(isMoving)
            }
        }
    }

    @ViewBuilder
    private func cellRow(_ cell: Cell) -> some View {
        switch cell.state {
        case .current:
            HStack {
                Text(cell.label)
                    .font(.body.monospaced())
                    .fontWeight(.medium)
                Spacer()
                Text("Ici")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.gray)
                    .clipShape(Capsule())
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("move-\(cell.label)")

        case .empty:
            Button {
                pending = Pending(row: cell.row, col: cell.col, occupant: nil)
            } label: {
                HStack {
                    Text(cell.label)
                        .font(.body.monospaced())
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .tint(.primary)
            .disabled(isMoving)
            .accessibilityIdentifier("move-\(cell.label)")

        case let .occupied(name, beverageType, color):
            Button {
                pending = Pending(
                    row: cell.row, col: cell.col,
                    occupant: Pending.Occupant(name: name)
                )
            } label: {
                HStack(spacing: 12) {
                    Text(cell.label)
                        .font(.body.monospaced())
                        .fontWeight(.medium)
                    BeverageBadge(beverageType: beverageType, color: color)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .disabled(isMoving)
            .accessibilityIdentifier("move-\(cell.label)")
        }
    }

    private var wineHeader: some View {
        HStack(spacing: 12) {
            BeverageBadge(beverageType: wineBeverageType, color: wineColor)
            VStack(alignment: .leading) {
                Text(wineName)
                    .font(.headline)
                if let vintage = wineVintage {
                    Text(verbatim: "\(vintage)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Actuellement en \(currentPosition)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

extension BottleMovePage {
    struct Group: Identifiable {
        let row: String
        let cells: [Cell]
        var id: String { row }
    }

    struct Cell: Identifiable {
        let row: String
        let col: Int
        let label: String
        let state: State
        var id: String { label }

        enum State {
            case empty
            case occupied(name: String, beverageType: BeverageType, color: WineColor?)
            case current
        }
    }

    private struct Pending: Identifiable {
        let id = UUID()
        let row: String
        let col: Int
        let occupant: Occupant?

        var position: String { "\(row)\(col)" }

        struct Occupant {
            let name: String
        }
    }
}

#Preview {
    NavigationStack {
        BottleMovePage(
            wineName: "Château Margaux",
            wineColor: .red,
            wineVintage: 2018,
            currentPosition: "A1",
            groups: (0..<3).map { rowIdx in
                let rowLetter = String(UnicodeScalar(65 + rowIdx)!)
                let cells: [BottleMovePage.Cell] = (1...4).map { col in
                    let label = "\(rowLetter)\(col)"
                    if label == "A1" {
                        return .init(row: rowLetter, col: col, label: label, state: .current)
                    }
                    if label == "B2" {
                        return .init(row: rowLetter, col: col, label: label, state: .occupied(name: "Pouilly-Fumé", beverageType: .wine, color: .white))
                    }
                    return .init(row: rowLetter, col: col, label: label, state: .empty)
                }
                return .init(row: rowLetter, cells: cells)
            },
            isMoving: false,
            onMoveConfirmed: { _, _ in }
        )
    }
}
