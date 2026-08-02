import XCTest

@MainActor
struct ScanFlowPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        try app.buttons["scan-photo-picker"].waitOrFail()
        return self
    }

    func selectPhotoFromPicker() throws -> ScanReviewPage {
        try app.buttons["scan-photo-picker"].tapOrFail()

        // In test mode (-UITestPhoto), tapping the button loads the bundled image
        // directly — no PHPicker interaction needed. Wait longer for AI scan.
        // After the analysis the flow lands straight on the editable review form.
        try app.navigationBars["Check the bottle"].waitOrFail(timeout: 15)

        return ScanReviewPage(app: app)
    }
}
