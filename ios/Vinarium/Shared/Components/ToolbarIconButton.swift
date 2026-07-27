import SwiftUI

/// Icon-only toolbar button. The `title` is kept purely for accessibility (VoiceOver);
/// only the SF Symbol is rendered. Used for cancel / close / back and secondary actions.
struct ToolbarIconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
        }
        .labelStyle(.iconOnly)
    }
}
