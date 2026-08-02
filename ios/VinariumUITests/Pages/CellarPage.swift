import XCTest

@MainActor
struct CellarPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["My Cellar"].waitOrFail()
        return self
    }

    func switchToCave() throws -> Self {
        try app.buttons["cellar-mode-Cave"].tapOrFail()
        return self
    }

    func switchToJournal() throws -> Self {
        try app.buttons["cellar-mode-Journal"].tapOrFail()
        return self
    }

    func verifyRowHeader(_ row: String) throws {
        let text = "Row \(row)"
        try app.staticTexts[text].waitOrFail(timeout: 4, "Row header '\(text)' not found")
    }

    func verifyJournalShowsEntry() throws {
        try app.staticTexts["In"].waitOrFail(timeout: 4, "no entry row in the journal")
    }

    func verifyJournalShowsExit() throws {
        try app.staticTexts["Out"].waitOrFail(timeout: 4, "no exit row in the journal")
    }

    func tapWine(named name: String) throws -> WineDetailPage {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        try app.buttons.matching(predicate).firstMatch.tapOrFail()
        return WineDetailPage(app: app)
    }
}
