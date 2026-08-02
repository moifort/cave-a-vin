import SwiftUI

enum BeverageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case wine
    case spirit
    case beer
    case sake
    case cider
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wine: String(localized: "Vin")
        case .spirit: String(localized: "Spiritueux")
        case .beer: String(localized: "Bière")
        case .sake: String(localized: "Saké")
        case .cider: String(localized: "Cidre")
        case .other: String(localized: "Autre")
        }
    }

    var icon: String {
        switch self {
        case .wine: "wineglass"
        case .spirit: "flame"
        case .beer: "mug"
        case .sake: "cup.and.saucer"
        case .cider: "applelogo"
        case .other: "questionmark.circle"
        }
    }

    /// First letter of the type, shown in the badge of non-wine beverages.
    var initial: String { String(label.prefix(1)).uppercased() }

    var displayColor: Color {
        switch self {
        case .wine: Color(red: 0.5, green: 0.05, blue: 0.1)      // bordeaux
        case .spirit: Color(red: 0.72, green: 0.45, blue: 0.2)   // amber
        case .beer: Color(red: 0.93, green: 0.72, blue: 0.23)    // gold
        case .sake: Color(red: 0.85, green: 0.85, blue: 0.78)    // rice
        case .cider: Color(red: 0.62, green: 0.75, blue: 0.22)   // apple
        case .other: Color(.systemGray)
        }
    }

    /// The producer goes by a different name depending on the beverage, and this drives
    /// the form's field label.
    var producerLabel: String {
        switch self {
        case .wine: String(localized: "Domaine")
        case .spirit: String(localized: "Distillerie")
        case .beer: String(localized: "Brasserie")
        case .sake: String(localized: "Kura")
        case .cider: String(localized: "Cidrerie")
        case .other: String(localized: "Producteur")
        }
    }
}
