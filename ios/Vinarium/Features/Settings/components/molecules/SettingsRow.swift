import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    /// Free text under the title: a value read at runtime (email, version, quota),
    /// so it is localized by its caller rather than looked up here.
    let subtitle: String?
    let tint: Color

    /// The badge box scales with Dynamic Type; the glyph is sized to a fixed
    /// fraction of it, so its inset stays constant at every text size.
    @ScaledMetric(relativeTo: .body) private var iconBadgeSize: CGFloat = 28
    private var glyphSize: CGFloat { iconBadgeSize * 0.5 }

    init(
        icon: String,
        title: LocalizedStringKey,
        subtitle: String? = nil,
        tint: Color = .accentColor
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
    }

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: icon)
                .font(.system(size: glyphSize))
                .foregroundStyle(.white)
                .frame(width: iconBadgeSize, height: iconBadgeSize)
                .background(
                    tint,
                    in: RoundedRectangle(cornerRadius: iconBadgeSize * 6 / 28, style: .continuous)
                )
        }
    }
}

#Preview {
    List {
        SettingsRow(icon: "person.crop.circle", title: "Profil", subtitle: "thibaut@example.com")
        SettingsRow(icon: "doc.text", title: "Changelog", subtitle: "v1.0", tint: .indigo)
        SettingsRow(icon: "square.grid.3x3.fill", title: "Cave", subtitle: "6 \u{00D7} 8", tint: .brown)
        SettingsRow(icon: "square.and.arrow.up", title: "Importer / Exporter", tint: .teal)
        SettingsRow(icon: "person.2.fill", title: "Partage", subtitle: "Bient\u{00F4}t disponible", tint: .gray)
    }
}
