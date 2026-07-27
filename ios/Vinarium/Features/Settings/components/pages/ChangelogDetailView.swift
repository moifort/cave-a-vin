import SwiftUI

struct ChangelogDetailView: View {
    let entry: ChangelogVersion

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        List {
            Section {
                if let date = entry.date {
                    LabeledInfoRow(
                        title: "Date",
                        value: Self.dateFormatter.string(from: date),
                        icon: "calendar"
                    )
                } else {
                    LabeledInfoRow(
                        title: "Date",
                        value: String(localized: "Non publiée"),
                        icon: "calendar"
                    )
                }
            }

            Section("Notes") {
                ForEach(entry.notes, id: \.self) { note in
                    Label(note, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                }
            }
        }
        .navigationTitle(entry.version)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(.tertiary)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogVersion(
                version: "2026.04.26",
                date: Date(),
                notes: [
                    "Écran Réglages.",
                    "Changelog visible.",
                    "Import / export JSON."
                ]
            )
        )
    }
}
