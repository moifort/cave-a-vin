import SwiftUI

/// Opens the detail page with the slot the bottle occupies, so the position is
/// readable without scrolling down to the cellar section.
struct WineCellarPositionSection: View {
    let position: String

    var body: some View {
        Section {
            Label {
                LabeledContent("Position") {
                    PositionBadge(position: position)
                }
            } icon: {
                Image(systemName: "cabinet")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("cellar-position-row")
        }
    }
}

#Preview {
    List {
        WineCellarPositionSection(position: "A3")
    }
}
