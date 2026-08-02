import XCTest

@MainActor
struct ConfirmationPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.alerts.buttons["Confirm"].tapOrFail()
        return self
    }

    func verifyWineName(_ name: String) throws {
        try app.staticTexts[name].waitOrFail()
    }

    func verifyPosition(_ position: String) throws {
        try app.staticTexts["Position: \(position)"].waitOrFail()
    }

    func tapDone() throws {
        try app.buttons["done-button"].tapOrFail()
    }
}
