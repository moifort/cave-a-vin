import SwiftUI

struct WineCellarSection: View {
    let position: String
    let dateIn: String
    let dateOut: String?
    let isInCellar: Bool
    var onRemoveRequested: () -> Void

    var body: some View {
        Section("Cave") {
            Label {
                LabeledContent("Position") {
                    PositionBadge(position: position)
                }
            } icon: {
                Image(systemName: "mappin.circle")
                    .foregroundStyle(.secondary)
            }
            Label {
                LabeledContent("Entr\u{00E9}e le", value: dateIn)
            } icon: {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
            }

            if let dateOut {
                Label {
                    LabeledContent("Sortie le", value: dateOut)
                } icon: {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(.red)
                }
            }

            if isInCellar {
                Button(role: .destructive) {
                    onRemoveRequested()
                } label: {
                    Label("Sortir de la cave", systemImage: "arrow.up.circle")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .accessibilityIdentifier("remove-from-cellar-button")
            }
        }
    }
}

#Preview {
    List {
        WineCellarSection(
            position: "A3",
            dateIn: "20 f\u{00E9}vr. 2026",
            dateOut: nil,
            isInCellar: true,
            onRemoveRequested: {}
        )
    }
}
