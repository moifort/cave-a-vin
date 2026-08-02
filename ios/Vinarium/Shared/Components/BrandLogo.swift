import SwiftUI

/// Branding mark for the login/onboarding screens: a small mosaic of bottle
/// capsules echoing the app icon, cascading in with a one-shot entrance
/// animation (no continuous loop).
struct BrandLogo: View {
    var capsuleSize: CGFloat = 34

    @State private var appeared = false

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: spacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, color in
                        Capsule2D(color: color, size: capsuleSize)
                            .scaleEffect(appeared ? 1 : 0.3)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(duration: 0.5, bounce: 0.4)
                                    .delay(Double(rowIndex + colIndex) * 0.06),
                                value: appeared
                            )
                    }
                }
                // Middle row nudged half a capsule to reproduce the icon's
                // diagonal, offset-grid rhythm.
                .offset(x: rowIndex == 1 ? (capsuleSize + spacing) / 2 : 0)
            }
        }
        .onAppear { appeared = true }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Vinarium"))
    }

    private var spacing: CGFloat { capsuleSize * 0.28 }

    // Palette sampled from the app icon (burgundy / rose / plum / gold / amber).
    private static let burgundy = Color(red: 0.55, green: 0.07, blue: 0.16)
    private static let rose = Color(red: 0.80, green: 0.20, blue: 0.25)
    private static let plum = Color(red: 0.42, green: 0.13, blue: 0.24)
    private static let gold = Color(red: 0.83, green: 0.68, blue: 0.35)
    private static let amber = Color(red: 0.85, green: 0.55, blue: 0.15)

    private static let rows: [[Color]] = [
        [plum, rose, gold],
        [burgundy, gold, amber],
        [gold, rose, burgundy],
    ]
}

/// A single capsule seen from above: a filled disc with a metallic rim and a
/// soft top highlight, mimicking the app icon's screw caps.
private struct Capsule2D: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(1.0), color.opacity(0.82)],
                    center: .init(x: 0.38, y: 0.32),
                    startRadius: 0,
                    endRadius: size * 0.75
                )
            )
            .overlay {
                // Recessed rim of the capsule.
                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: size * 0.06)
                    .padding(size * 0.14)
            }
            .overlay {
                Circle()
                    .strokeBorder(.black.opacity(0.12), lineWidth: max(1, size * 0.03))
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.2), radius: size * 0.06, x: 0, y: size * 0.05)
    }
}

#Preview("Capsules") {
    HStack(spacing: 24) {
        Capsule2D(color: Color(red: 0.5, green: 0.05, blue: 0.1), size: 40)
        Capsule2D(color: Color(red: 0.72, green: 0.45, blue: 0.2), size: 64)
        Capsule2D(color: Color(red: 0.93, green: 0.72, blue: 0.23), size: 96)
    }
    .padding(40)
}

#Preview("Logo") {
    BrandLogo()
        .padding(40)
}

#Preview("Sombre") {
    BrandLogo()
        .padding(40)
        .preferredColorScheme(.dark)
}
