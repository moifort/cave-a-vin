import SwiftUI

/// The waiting step of the AI analysis, presented as a sheet over the camera: the
/// `SiriLoader` orb on an `.ultraThinMaterial` scrim with its message. The material
/// follows the system appearance instead of forcing black, and the orb (which carries
/// its own dark scene) floats on it without dragging a disc along. Purely
/// presentational.
struct ScanAnalyzingPage: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                SiriLoader()

                VStack(spacing: 12) {
                    Text("Analyse en cours")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Identification de l'étiquette...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview("Light") {
    Color(.systemBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ScanAnalyzingPage()
        }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    Color(.systemBackground)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ScanAnalyzingPage()
        }
        .preferredColorScheme(.dark)
}
