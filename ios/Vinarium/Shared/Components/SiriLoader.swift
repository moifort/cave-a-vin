import SwiftUI

/// The "listening" Siri orb: eleven layered gradient blobs (vector PDF assets in
/// `Assets.xcassets/Siri/`) rotating and hue-shifting, composited with `.hardLight`.
/// A port of Amos Gyamfi's ListeningSiriAnimation
/// (GetStream/purposeful-ios-animations) — same assets, transforms and blend,
/// driven here by a seamless oscillation. The phase oscillates smoothly between the
/// two end poses (a cosine ease), so the motion reads as one endless loop with no
/// visible start or end — unlike a sawtooth, which would snap pose-B back to pose-A
/// every cycle. Self-contained and transparent: the `.hardLight` blend is confined to
/// a local black stage, and that stage is then keyed out by its own luminance, so the
/// orb floats on a light or a dark backdrop alike.
/// Respects Reduce Motion by holding a single static frame. Purely presentational.
struct SiriLoader: View {
    /// Layout footprint; the artwork (largest layer ≈ 640 pt) is scaled to fit it.
    var size: CGFloat = 260

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the loop starts at its midpoint on appear.
    @State private var start = Date()

    /// Seconds for one pose-A → pose-B traversal; the full oscillation (A → B → A)
    /// takes twice this, all seamless.
    private let period: TimeInterval = 12
    private var scale: CGFloat { size / 640 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.5 : phase(at: context.date)
            // The stage is drawn twice: once as the visible artwork, once as its own
            // mask. `luminanceToAlpha` turns the mask copy's brightness into opacity,
            // so the black backdrop the blend needs becomes fully transparent while
            // the lit blobs stay opaque — the orb floats on whatever is behind it
            // instead of dragging a black disc along.
            stage(phase: t)
                .mask {
                    stage(phase: t)
                        .luminanceToAlpha()
                        .mask { fadeToRound }
                }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The orb composited over the local black backdrop its `.hardLight` blend
    /// requires, sealed into one layer so the blend never reaches the enclosing view.
    private func stage(phase t: Double) -> some View {
        orb(phase: t)
            .blendMode(.hardLight)
            .scaleEffect(scale)
            .frame(width: size, height: size)
            .background(Color.black)
            .compositingGroup()
    }

    /// Radial fade that rounds off the wobbling blobs so they read as one steady orb.
    private var fadeToRound: some View {
        RadialGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.30),
                .init(color: .clear, location: 0.66),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
    }

    /// Cycle position in `0...1` (0 and 1 are the two end poses); starts at 0.5.
    /// A raised-cosine ease oscillates 0 → 1 → 0 forever: position AND velocity are
    /// continuous at the turning points, so the loop has no visible seam or restart
    /// (a `mod 1` sawtooth would jump pose-B → pose-A once per period). The `+ 0.25`
    /// offset makes the loop begin at its midpoint (0.5) on appear.
    private func phase(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(start)
        let cycle = elapsed / (period * 2) + 0.25
        return (1 - cos(2 * .pi * cycle)) / 2
    }

    /// Linear blend between the two end poses at the given cycle position.
    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    private func orb(phase t: Double) -> some View {
        ZStack {
            Image("shadow")
            Image("icon-bg")

            Image("pink-top")
                .rotationEffect(.degrees(mix(320, -360, t)))
                .hueRotation(.degrees(mix(-270, 60, t)))

            Image("pink-left")
                .rotationEffect(.degrees(mix(-360, 180, t)))
                .hueRotation(.degrees(mix(-220, 300, t)))

            Image("blue-middle")
                .rotationEffect(.degrees(mix(-360, 420, t)))
                .hueRotation(.degrees(mix(-150, 0, t)))
                .rotation3DEffect(.degrees(75), axis: (x: mix(1, 5, t), y: 0, z: 0))

            Image("blue-right")
                .rotationEffect(.degrees(mix(-360, 420, t)))
                .hueRotation(.degrees(mix(720, -50, t)))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: mix(-5, 15, t)))

            Image("intersect")
                .rotationEffect(.degrees(mix(30, -420, t)))
                .hueRotation(.degrees(mix(0, 720, t)))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: 1, z: 1), perspective: mix(5, -5, t))

            Image("green-right")
                .rotationEffect(.degrees(mix(-180, 480, t)))
                .hueRotation(.degrees(mix(300, -15, t)))
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: mix(-1, 1, t), z: 0), perspective: mix(-1, 1, t))

            Image("green-left")
                .rotationEffect(.degrees(mix(240, -480, t)))
                .hueRotation(.degrees(mix(180, 50, t)))
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: mix(-5, 15, t), z: 0))

            Image("bottom-pink")
                .rotationEffect(.degrees(mix(400, -360, t)))
                .hueRotation(.degrees(mix(0, 230, t)))
                .opacity(0.25)
                .blendMode(.multiply)
                .rotation3DEffect(.degrees(75), axis: (x: 5, y: mix(1, -45, t), z: 0))

            Image("highlight")
                .rotationEffect(.degrees(mix(360, 250, t)))
                .hueRotation(.degrees(mix(0, 230, t)))
        }
    }
}

#Preview("On a light background") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        SiriLoader()
    }
    .preferredColorScheme(.light)
}

#Preview("On a dark background") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        SiriLoader()
    }
    .preferredColorScheme(.dark)
}
