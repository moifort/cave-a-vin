import SwiftUI

/// The app's full screen loading state: the swirling wine glass above a short
/// caption, centered in all available space. Use it for a view whose content is
/// not ready yet, instead of a bare `ProgressView` pinned inside a list row;
/// small inline waits (buttons, toolbar items, rows) keep the standard spinner.
struct LoadingStateView: View {
    var label: LocalizedStringKey = "Chargement..."

    var body: some View {
        VStack(spacing: 20) {
            WineGlassLoader()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingStateView()
}
