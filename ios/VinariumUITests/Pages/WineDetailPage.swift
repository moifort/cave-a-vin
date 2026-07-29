import XCTest

@MainActor
struct WineDetailPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["Fermer"].waitOrFail()
        return self
    }

    func verifyWineName(_ name: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        try app.staticTexts.matching(predicate).firstMatch.waitOrFail(timeout: 4, "Wine name '\(name)' not found")
    }

    func verifyCellarSection() throws {
        app.swipeUp()
        try app.staticTexts["Cave"].waitOrFail(timeout: 4, "'Cave' section not found")
    }

    func verifyConsumptionSection() throws {
        app.swipeUp()
        try app.staticTexts["Consommé"].waitOrFail(timeout: 4, "'Consommé' section not found")
    }

    func tapRemoveFromCellar() throws -> ConsumptionPage {
        try openRemovalDialog()
        try app.buttons["choice-consume"].firstMatch.tapOrFail()
        return ConsumptionPage(app: app)
    }

    func tapRemoveAndChooseGift() throws -> GiftPage {
        try openRemovalDialog()
        try app.buttons["choice-gift"].firstMatch.tapOrFail()
        return GiftPage(app: app)
    }

    /// Two different controls carry `remove-from-cellar-button`: the toolbar's
    /// "Sortir" and the cellar section's "Sortir de la cave". Both open the same
    /// dialog, so aim at the toolbar one — it is the one always on screen.
    private func openRemovalDialog() throws {
        app.swipeUp()
        let inToolbar = app.navigationBars.buttons["remove-from-cellar-button"].firstMatch
        if inToolbar.waitForExistence(timeout: 4) {
            inToolbar.tap()
            return
        }
        try app.buttons["remove-from-cellar-button"].firstMatch.tapOrFail()
    }

    func verifyGiftSection() throws {
        app.swipeUp()
        try app.staticTexts["Offert"].waitOrFail(timeout: 4, "'Offert' section not found")
    }

    func verifyRecommendationSection() throws {
        app.swipeUp()
        try app.staticTexts["Conseillé"].waitOrFail(timeout: 4, "'Conseillé' section not found")
    }

    /// Flags the bottle as a favorite through the detail menu and its sheet. A
    /// rating does not make a favorite: the flag is its own field on the note.
    func addToFavorites() throws {
        try tapMenuItem(identifier: "menu-favorite-button", label: "Ajouter aux favoris")
        try app.buttons["confirm-favorite-button"].tapOrFail(timeout: 10)
    }

    func tapDelete() throws {
        try tapMenuItem(identifier: "delete-wine-button", label: "Supprimer")
        try app.buttons["choice-delete"].firstMatch.tapOrFail()
    }

    /// Opens the "..." menu and taps one of its items. SwiftUI does not carry
    /// `accessibilityIdentifier` onto the items of a `Menu` — they come out as
    /// system elements labelled by their title — so the label is what actually
    /// matches; the identifier is tried first in case a future iOS propagates it.
    private func tapMenuItem(identifier: String, label: String) throws {
        try app.buttons["wine-detail-menu"].tapOrFail()
        let byIdentifier = app.buttons[identifier].firstMatch
        if byIdentifier.waitForExistence(timeout: 2) {
            byIdentifier.tap()
            return
        }
        try app.buttons[label].firstMatch.tapOrFail()
    }

    func close() throws {
        try app.buttons["Fermer"].tapOrFail()
    }
}
