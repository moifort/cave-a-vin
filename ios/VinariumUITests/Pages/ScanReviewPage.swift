import XCTest

@MainActor
struct ScanReviewPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Check the bottle"].waitOrFail()
        return self
    }

    func clearAndTypeName(_ name: String) throws -> Self {
        let nameField = try app.textFields["review-name-field"].waitOrFail()
        // Deleting character by character rather than triple-tapping to select:
        // the selection sometimes does not take, and the new name then lands
        // inside the scanned one ("Vin Test CadeaChâteau Vinarium") — a failure
        // that only surfaces three steps later, when the bottle cannot be found.
        for attempt in 1...2 {
            // Tapping the field puts the caret wherever the tap landed, mid-word,
            // and deletes only eat what is left of it. Tapping past the last
            // character (the field is trailing-aligned) puts it at the end.
            nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
            let current = (nameField.value as? String) ?? ""
            if !current.isEmpty {
                nameField.typeText(
                    String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 5)
                )
            }
            nameField.typeText(name)
            if (nameField.value as? String) == name { return self }
            if attempt == 2 {
                let actual = (nameField.value as? String) ?? "<nil>"
                let message = "Name field holds '\(actual)' instead of '\(name)'"
                XCTFail(message)
                throw UITestFailure(message: message)
            }
        }
        return self
    }

    func selectColor(_ color: String) throws -> Self {
        try app.buttons["Color"].tapOrFail()
        try app.buttons[color].tapOrFail()
        return self
    }

    func typeVintage(_ vintage: String) throws -> Self {
        let vintageField = try app.textFields["Year"].waitOrFail()
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
        let field = app.textFields["review-recommender-field"].firstMatch
        app.scrollTo(field)
        try field.waitOrFail("'Recommended by' field not reachable")
        field.tap()
        field.typeText(name)
        return self
    }

    /// Opens the destination popup (the plus button) then taps the requested choice.
    private func chooseDestination(_ identifier: String) throws {
        app.swipeUp()
        try app.buttons["review-save-button"].tapOrFail()
        // A confirmationDialog surfaces each button twice in the accessibility
        // tree, so an exact subscript query is ambiguous — same reason the
        // detail page's dialogs go through firstMatch.
        try app.buttons[identifier].firstMatch.tapOrFail()
    }

    /// Adds to the cellar, which chains into the placement step.
    func addToCellar() throws -> PlacementPage {
        try chooseDestination("choice-cellar")
        return PlacementPage(app: app)
    }

    /// Turns on the form's inline favorite toggle (tasting section).
    func markAsFavorite() throws -> Self {
        let toggle = app.switches["review-favorite-toggle"].firstMatch
        app.scrollTo(toggle)
        try toggle.waitOrFail("Favorite toggle not reachable")
        toggle.switches.firstMatch.tap()
        return self
    }

    func justSave() throws {
        try chooseDestination("choice-justSave")
    }
}
