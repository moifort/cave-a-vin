import Foundation

/// Structured subtype of a beverage (rum, porto, blonde, junmai…). A single flat
/// enum covers every type: which values a type accepts is carried by `allowed(for:)`,
/// which mirrors the server's SUBTYPES_BY_BEVERAGE and must be kept in sync.
enum BeverageSubtype: String, Codable, CaseIterable, Identifiable, Sendable {
    // wine
    case sparkling
    case sweet
    case lateHarvest = "late-harvest"
    case vinJaune = "vin-jaune"
    case porto
    case fortified
    // spirit
    case rum
    case whisky
    case gin
    case vodka
    case cognac
    case armagnac
    case tequila
    case liqueur
    case eauDeVie = "eau-de-vie"
    // beer
    case blonde
    case blanche
    case amber
    case brune
    case ipa
    case stout
    case pils
    case triple
    // sake
    case junmai
    case ginjo
    case daiginjo
    case honjozo
    case nigori
    // cider
    case brut
    case doux
    case demiSec = "demi-sec"
    case poire
    // every type
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sparkling: String(localized: "Pétillant")
        case .sweet: String(localized: "Moelleux")
        case .lateHarvest: String(localized: "Vendanges tardives")
        case .vinJaune: String(localized: "Vin jaune")
        case .porto: String(localized: "Porto")
        case .fortified: String(localized: "Vin muté")
        case .rum: String(localized: "Rhum")
        case .whisky: String(localized: "Whisky")
        case .gin: String(localized: "Gin")
        case .vodka: String(localized: "Vodka")
        case .cognac: String(localized: "Cognac")
        case .armagnac: String(localized: "Armagnac")
        case .tequila: String(localized: "Tequila/Mezcal")
        case .liqueur: String(localized: "Liqueur")
        case .eauDeVie: String(localized: "Eau-de-vie")
        case .blonde: String(localized: "Blonde")
        case .blanche: String(localized: "Blanche")
        case .amber: String(localized: "Ambrée")
        case .brune: String(localized: "Brune")
        case .ipa: String(localized: "IPA")
        case .stout: String(localized: "Stout")
        case .pils: String(localized: "Pils/Lager")
        case .triple: String(localized: "Triple")
        case .junmai: String(localized: "Junmai")
        case .ginjo: String(localized: "Ginjo")
        case .daiginjo: String(localized: "Daiginjo")
        case .honjozo: String(localized: "Honjozo")
        case .nigori: String(localized: "Nigori")
        case .brut: String(localized: "Brut")
        case .doux: String(localized: "Doux")
        case .demiSec: String(localized: "Demi-sec")
        case .poire: String(localized: "Poiré")
        case .other: String(localized: "Autre")
        }
    }

    /// Sparkling sake reads differently from sparkling wine, though the value is shared.
    func label(for beverageType: BeverageType) -> String {
        if self == .sparkling && beverageType == .sake { return String(localized: "Saké pétillant") }
        return label
    }

    /// Subtypes that can be offered for a given beverage type.
    static func allowed(for beverageType: BeverageType) -> [BeverageSubtype] {
        switch beverageType {
        case .wine: [.sparkling, .sweet, .lateHarvest, .vinJaune, .porto, .fortified, .other]
        case .spirit: [.rum, .whisky, .gin, .vodka, .cognac, .armagnac, .tequila, .liqueur, .eauDeVie, .other]
        case .beer: [.blonde, .blanche, .amber, .brune, .ipa, .stout, .pils, .triple, .other]
        case .sake: [.junmai, .ginjo, .daiginjo, .honjozo, .nigori, .sparkling, .other]
        case .cider: [.brut, .doux, .demiSec, .poire, .other]
        case .other: [.other]
        }
    }
}
