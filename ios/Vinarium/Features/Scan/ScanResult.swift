import Foundation

struct ScanResult: Decodable, Sendable {
    /// False when the image was not an identifiable label: it opens the "no result"
    /// screen rather than an empty form to fill in.
    let recognized: Bool
    let name: String
    let beverageType: BeverageType
    let domain: String?
    let vintage: Int?
    let appellation: String?
    let region: String?
    let country: String?
    let color: WineColor?
    let subtype: BeverageSubtype?
    let grapeVarieties: [String]
    let alcoholContent: Double?
    let classification: String?
    let drinkFrom: Int?
    let drinkUntil: Int?
    let estimatedPrice: Double?
}
