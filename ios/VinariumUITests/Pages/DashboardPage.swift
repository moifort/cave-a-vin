import XCTest

@MainActor
struct DashboardPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.navigationBars["Home"].waitOrFail()
        return self
    }

    @discardableResult
    func refresh() -> Self {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)
        return self
    }

    func verifyBottleCount(_ expected: String) throws {
        let widget = try app.buttons["stat-bottles"].waitOrFail()
        XCTAssertTrue(widget.label.contains(expected), "stat-bottles label '\(widget.label)' should contain '\(expected)'")
    }

    func verifyTotalValue(_ expected: String) throws {
        let widget = try app.buttons["stat-value"].waitOrFail()
        XCTAssertTrue(widget.label.contains(expected), "stat-value label '\(widget.label)' should contain '\(expected)'")
    }

    func verifyJournalContains(_ wineName: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", wineName)
        let element = app.staticTexts.matching(predicate).firstMatch
        if !element.waitForExistence(timeout: 3) {
            let button = app.buttons.matching(predicate).firstMatch
            try button.waitOrFail(timeout: 2, "'\(wineName)' not found in journal")
        }
    }

    func verifyJournalShowsEntry() throws {
        // The direction badge is an image carrying it as its accessibility label,
        // so match that exactly. The French version searched staticTexts for
        // "entrée" and was really matching the "Dernière entrée le ..." caption,
        // never the badge; in English, a CONTAINS on "in" would match "In cellar"
        // and pass whatever the journal shows.
        try app.images["In"].firstMatch.waitOrFail(timeout: 15, "no entry badge in the journal")
    }

    func verifyFavoritesContains(_ wineName: String) throws {
        let predicate = NSPredicate(format: "label CONTAINS %@", wineName)
        let element = app.staticTexts.matching(predicate).firstMatch
        if !element.waitForExistence(timeout: 4) {
            let button = app.buttons.matching(predicate).firstMatch
            try button.waitOrFail(timeout: 2, "'\(wineName)' not found in favorites")
        }
    }

    func tapWine(named name: String) throws -> WineDetailPage {
        let predicate = NSPredicate(format: "label CONTAINS %@", name)
        try app.buttons.matching(predicate).firstMatch.tapOrFail()
        return WineDetailPage(app: app)
    }
}
