import SwiftUI

struct GradientWidget: View {
    let title: LocalizedStringKey
    let value: String
    var denominator: String? = nil
    let subtitle: LocalizedStringKey
    let gradient: [Color]
    var backgroundImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: value)
                    .font(.largeTitle.bold())
                if let denominator {
                    Text(verbatim: denominator)
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .foregroundStyle(.white)
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Spacer()

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background {
            if let bg = backgroundImage {
                Image(bg)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.4))
            } else {
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(.rect(cornerRadius: 20))
    }
}

#Preview {
    HStack(spacing: 12) {
        GradientWidget(
            title: "En cave",
            value: "41",
            denominator: "/48",
            subtitle: "Bouteilles",
            gradient: [Color(red: 0.55, green: 0.25, blue: 0.8), Color(red: 0.75, green: 0.45, blue: 0.95)]
        )
        GradientWidget(
            title: "Valeur",
            value: "450 \u{20AC}",
            subtitle: "Total",
            gradient: [Color(red: 0.15, green: 0.65, blue: 0.45), Color(red: 0.3, green: 0.8, blue: 0.55)]
        )
    }
    .frame(height: 140)
    .padding()
}
