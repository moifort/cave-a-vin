import XCTest

@MainActor
struct ConsumptionPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Consumption"].waitOrFail()
        return self
    }

    func tapStar(_ number: Int) throws -> Self {
        try app.buttons["star-rating-\(number)"].tapOrFail()
        return self
    }

    func typeTastingNotes(_ notes: String) -> Self {
        let notesField = app.textViews["Vos impressions..."]
        if notesField.waitForExistence(timeout: 15) {
            notesField.tap()
            notesField.typeText(notes)
        }
        return self
    }

    func tapConfirm() throws {
        try app.buttons["confirm-consumption-button"].tapOrFail()
    }
}
