import SwiftUI

struct PresetChoicePage: View {
    let presets: [CellarPreset]
    var onSelect: (PresetChoice) -> Void
    var onNext: () -> Void
    var onBack: () -> Void
    /// Leading button. Defaults to a "Retour" back-chevron (onboarding, where
    /// onBack navigates to the previous step); a sheet-first step passes a
    /// "Fermer" xmark so the icon matches its dismiss behavior.
    var backTitle: LocalizedStringKey = "Retour"
    var backSystemImage: String = "chevron.left"
    var backRole: ButtonRole? = nil

    @State private var searchText = ""

    // MARK: Grouping (Settings/Contacts-style: sections by leading letter)

    private struct LetterSection: Identifiable {
        let id: String
        let letter: String
        let models: [CellarPreset]
    }

    private var query: String {
        normalized(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isSearching: Bool { !query.isEmpty }

    private func letter(for preset: CellarPreset) -> String {
        let first = String(preset.brand.prefix(1)).uppercased()
        return first.range(of: "[A-Z]", options: .regularExpression) != nil ? first : "#"
    }

    private var letterSections: [LetterSection] {
        let visible = isSearching
            ? presets.filter { normalized($0.displayName).contains(query) }
            : presets
        return Dictionary(grouping: visible, by: letter)
            .map { key, models in
                LetterSection(
                    id: key,
                    letter: key,
                    models: models.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted { ($0.letter == "#" ? 1 : 0, $0.letter) < ($1.letter == "#" ? 1 : 0, $1.letter) }
    }

    // MARK: Body

    var body: some View {
        List {
            Section {
                customRow
            }

            ForEach(letterSections) { section in
                Section {
                    ForEach(section.models) { preset in
                        row(title: preset.displayName, subtitle: subtitle(for: preset)) {
                            choose(.preset(preset))
                        }
                        .accessibilityIdentifier("onboarding-preset-\(preset.id)")
                    }
                } header: {
                    Text(section.letter)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Rechercher (marque, modèle)")
        .navigationTitle("Votre cave")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIconButton(
                    title: backTitle,
                    systemImage: backSystemImage,
                    role: backRole,
                    action: onBack
                )
            }
        }
    }

    // MARK: Rows

    private var customRow: some View {
        Button {
            choose(.custom)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 29, height: 29)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sur mesure").font(.body).fontWeight(.medium)
                    Text("Je saisis moi-même les dimensions")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                chevron
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .accessibilityIdentifier("onboarding-preset-custom")
    }

    private func row(
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).fontWeight(.medium)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                chevron
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    // MARK: Helpers

    private func choose(_ choice: PresetChoice) {
        onSelect(choice)
        onNext()
    }

    private func subtitle(for preset: CellarPreset) -> String {
        let zones =
            preset.zones == 1
            ? String(localized: "1 zone") : String(localized: "\(preset.zones) zones")
        return String(localized: "\(preset.bottles) bouteilles · \(zones)")
    }

    private func normalized(_ string: String) -> String {
        string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}

#Preview {
    NavigationStack {
        PresetChoicePage(
            presets: CellarPreset.all,
            onSelect: { _ in },
            onNext: {},
            onBack: {}
        )
    }
}
