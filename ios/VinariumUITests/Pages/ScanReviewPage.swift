import XCTest

@MainActor
struct ScanReviewPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Vérifier la bouteille"].waitOrFail()
        return self
    }

    func clearAndTypeName(_ name: String) throws -> Self {
        let nameField = try app.textFields["review-name-field"].waitOrFail()
        // Triple-tap to select all text, then type to replace
        nameField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        nameField.typeText(name)
        return self
    }

    func selectColor(_ color: String) throws -> Self {
        try app.buttons["Couleur"].tapOrFail()
        try app.buttons[color].tapOrFail()
        return self
    }

    func typeVintage(_ vintage: String) throws -> Self {
        let vintageField = try app.textFields["Année"].waitOrFail()
        vintageField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        vintageField.typeText(vintage)
        return self
    }

    func typePrice(_ price: String) throws -> Self {
        app.swipeUp()
        let priceField = try app.textFields["review-price-field"].waitOrFail()
        priceField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        priceField.typeText(price)
        return self
    }

    func typeRecommenderName(_ name: String) throws -> Self {
        let field = try app.textFields["review-recommender-field"].waitOrFail()
        field.tap()
        field.typeText(name)
        return self
    }

    /// Ouvre la popup de choix (bouton +) puis tape le choix demandé.
    private func chooseDestination(_ identifier: String) throws {
        app.swipeUp()
        try app.buttons["review-save-button"].tapOrFail()
        // A confirmationDialog surfaces each button twice in the accessibility
        // tree, so an exact subscript query is ambiguous — same reason the
        // detail page's dialogs go through firstMatch.
        try app.buttons[identifier].firstMatch.tapOrFail()
    }

    /// Ajout vers la cave : enchaîne sur le placement.
    func addToCellar() throws -> PlacementPage {
        try chooseDestination("choice-cellar")
        return PlacementPage(app: app)
    }

    /// Active le toggle « Favori » inline du formulaire (section Dégustation).
    func markAsFavorite() throws -> Self {
        let toggle = try app.switches["review-favorite-toggle"].waitOrFail()
        toggle.switches.firstMatch.tap()
        return self
    }

    func justSave() throws {
        try chooseDestination("choice-justSave")
    }
}
