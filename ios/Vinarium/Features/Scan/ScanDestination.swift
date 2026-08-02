import Foundation

/// What to do with the identified bottle, picked from the popup
/// (`confirmationDialog`) that the form's plus button opens once every field is
/// filled in.
enum ScanDestination: String, CaseIterable, Identifiable, Sendable {
    case cellar
    case justSave

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cellar: String(localized: "Ranger en cave")
        case .justSave: String(localized: "Juste enregistrer")
        }
    }

    var icon: String {
        switch self {
        case .cellar: "square.grid.3x3"
        case .justSave: "checkmark.circle"
        }
    }

    var accessibilityId: String { "choice-\(rawValue)" }
}
