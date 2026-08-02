import SwiftUI

/// The "nothing found" phase of the flow sheet: the AI recognized nothing on the
/// photo. Rendered inside the sheet's `NavigationStack` (no stack of its own); closing
/// or retrying falls back to the camera to take another photo.
struct ScanNoResultPage: View {
    let onClose: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Aucune étiquette détectée", systemImage: "text.magnifyingglass")
        } description: {
            Text("L'IA n'a rien trouvé à identifier ici. Réessaie avec une photo plus nette.")
        } actions: {
            Button("Réessayer") { onClose() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 44)
        }
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer", systemImage: "xmark") { onClose() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScanNoResultPage(onClose: {})
    }
}
