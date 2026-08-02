import MapKit
import SwiftUI

struct DiscoveryLocationDraft: Sendable, Equatable {
    var latitude: Double
    var longitude: Double
    var placeName: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct LocationEditorSheet: View {
    let initial: DiscoveryLocationDraft?
    let onConfirm: (DiscoveryLocationDraft?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchModel = LocationSearchModel()
    @State private var searchQuery = ""
    @State private var resolvingId: String?
    @State private var isClearing = false
    @FocusState private var searchFocused: Bool

    /// The badge box scales with Dynamic Type; the glyph is sized to a fixed
    /// fraction of it, so its inset stays constant at every text size.
    @ScaledMetric(relativeTo: .subheadline) private var iconBadgeSize: CGFloat = 28
    private var glyphSize: CGFloat { iconBadgeSize * 0.5 }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            resultsList
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .task {
            searchFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Ajuster le lieu")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Fermer"))

                Spacer()

                Button("R\u{00E9}tablir") {
                    reset()
                }
                .foregroundStyle(.red)
                .disabled(!hasUserInput)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("", text: $searchQuery, prompt: Text("Rechercher").foregroundStyle(.secondary))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Effacer la recherche"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .onChange(of: searchQuery) { _, newValue in
            searchModel.update(query: newValue)
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        List {
            Section {
                Button {
                    Task { await clearLocation() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: glyphSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: iconBadgeSize, height: iconBadgeSize)
                            .background(Circle().fill(.red))

                        Text("Aucun lieu")
                            .foregroundStyle(.primary)

                        Spacer()

                        if isClearing {
                            ProgressView()
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isClearing)
            }

            if !searchModel.suggestions.isEmpty {
                Section("Lieux sur le plan") {
                    ForEach(searchModel.suggestions, id: \.id) { completion in
                        SuggestionRow(
                            title: completion.title,
                            subtitle: completion.subtitle,
                            isResolving: resolvingId == completion.id
                        ) {
                            Task { await select(completion) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private var hasUserInput: Bool {
        !searchQuery.isEmpty || !searchModel.suggestions.isEmpty
    }

    private func reset() {
        searchQuery = ""
        searchModel.update(query: "")
    }

    private func clearLocation() async {
        guard !isClearing else { return }
        isClearing = true
        defer { isClearing = false }
        await onConfirm(nil)
        dismiss()
    }

    private func select(_ completion: MKLocalSearchCompletion) async {
        guard resolvingId == nil else { return }
        resolvingId = completion.id
        defer { resolvingId = nil }

        guard let coordinate = await resolveCoordinate(for: completion) else { return }
        let draft = DiscoveryLocationDraft(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            placeName: composedPlaceName(for: completion)
        )
        await onConfirm(draft)
        dismiss()
    }

    private func resolveCoordinate(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }

    private func composedPlaceName(for completion: MKLocalSearchCompletion) -> String {
        if completion.subtitle.isEmpty { return completion.title }
        return "\(completion.title), \(completion.subtitle)"
    }
}

// MARK: - Suggestion row

private struct SuggestionRow: View {
    let title: String
    let subtitle: String
    let isResolving: Bool
    let action: () -> Void

    /// The badge box scales with Dynamic Type; the glyph is sized to a fixed
    /// fraction of it, so its inset stays constant at every text size.
    @ScaledMetric(relativeTo: .subheadline) private var iconBadgeSize: CGFloat = 28
    private var glyphSize: CGFloat { iconBadgeSize * 0.5 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "mappin")
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: iconBadgeSize, height: iconBadgeSize)
                    .background(Circle().fill(.blue))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isResolving {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isResolving)
    }
}

// MARK: - Search model

@MainActor
@Observable
final class LocationSearchModel: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

extension MKLocalSearchCompletion {
    var id: String { "\(title)|\(subtitle)" }
}

#Preview("Suggestion rows") {
    List {
        SuggestionRow(
            title: "Château Vinarium",
            subtitle: "33250 Pauillac",
            isResolving: false,
            action: {}
        )
        SuggestionRow(
            title: "Caviste du Marché",
            subtitle: "",
            isResolving: true,
            action: {}
        )
    }
}

#Preview("Empty") {
    LocationEditorSheet(initial: nil) { _ in }
}

#Preview("Pre-filled") {
    LocationEditorSheet(
        initial: DiscoveryLocationDraft(
            latitude: 48.8769,
            longitude: 2.3370,
            placeName: "Paris - 9e Arr."
        )
    ) { _ in }
}
