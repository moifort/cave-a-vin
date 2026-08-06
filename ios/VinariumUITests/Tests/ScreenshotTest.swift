import XCTest

/// Captures the screens the README and the App Store show, from a cellar that
/// was filled beforehand by `scripts/seed-screenshot-cellar.ts`.
///
/// Deliberately NOT a `BaseUITest`: the scenarios there each sign in as a fresh
/// account and walk the wizard, which is exactly what must not happen here — a
/// brand new cellar is an empty grid, and an empty grid photographs badly. This
/// signs into the one seeded account instead and lands straight on a stocked
/// dashboard.
///
/// Run through `scripts/screenshots.sh`, which brings up the emulators, the
/// server and the seed. Running it alone captures whatever the simulator
/// happens to show, which is a sign-in screen.
@MainActor
final class ScreenshotTest: XCTestCase {
    /// The account the seed script filled. Fixed on both sides on purpose.
    private let account = "screenshots@vinarium.test"

    /// The language the app runs in, so one run per App Store locale can be
    /// captured without touching the test.
    ///
    /// Read from a file rather than the environment: `TEST_RUNNER_<NAME>=value`
    /// on the xcodebuild command line never reached this process — the run came
    /// out in French while the orchestrator was asking for English, and it
    /// silently overwrote the French captures. A file the script writes and the
    /// test reads has no such ambiguity, and this test already talks to the
    /// working copy through `#filePath` to save its PNGs.
    private var language: String {
        let path = repositoryRoot.appendingPathComponent("build/screenshot-language")
        let value = (try? String(contentsOf: path, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value! : "fr"
    }

    /// Where the PNGs land under `screenshots/`. French goes to the root, which
    /// is what the README embeds; every other language gets its own directory.
    private var subdirectory: String { language == "fr" ? "" : language }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // VinariumUITests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // repository root
    }

    var app: XCUIApplication!

    override func setUp() async throws {
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale(for: language),
            "-serverURL", "http://127.0.0.1:3000",
            "-uiTestAuthEmulator", "127.0.0.1:9099",
            "-uiTestAccount", account,
            // Replaces the camera with the bundled label, so the scan screen
            // shows a viewfinder rather than a permission prompt.
            "-UITestPhoto",
        ]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    /// Opens a tab, never by label: the page objects the scenarios use assert on
    /// English copy, and this runs in each of the seven shipped languages.
    ///
    /// Three ways in, narrowest first. The identifier `ContentView` puts on the
    /// tab is the intent; the position is the safety net, because an identifier
    /// set on a `Tab`'s label does not reliably surface on the button the tab
    /// bar builds from it — the same code passed one run and failed the next,
    /// depending on when the accessibility snapshot was taken.
    private func open(_ tab: String, at index: Int) throws {
        for candidate in [app.tabBars.buttons["tab-\(tab)"], app.buttons["tab-\(tab)"]] {
            if candidate.waitForExistence(timeout: 10) {
                candidate.tap()
                return
            }
        }
        try app.tabBars.buttons.element(boundBy: index).tapOrFail()
    }

    func testCaptureAllScreenshots() throws {
        try app.tabBars.firstMatch.waitOrFail()

        try open("home", at: 0)
        // The stats row only exists once the dashboard has its numbers, so this
        // waits out the loading state rather than photographing a spinner.
        // Matched on any element type: the tile is a button, which SwiftUI may
        // expose as one or fold into its container depending on the style.
        try app.descendants(matching: .any).matching(identifier: "stat-bottles").firstMatch
            .waitOrFail()
        save("dashboard")

        try open("cellar", at: 1)
        try app.buttons["cellar-mode-Cave"].tapOrFail()
        save("cellar")

        try app.buttons["cellar-mode-Journal"].tapOrFail()
        save("journal")

        try open("wines", at: 2)
        let firstWine = app.collectionViews.buttons.firstMatch
        try firstWine.waitOrFail()
        save("wine-list")

        try firstWine.tapOrFail()
        // The toolbar menu, not the cellar actions: those only exist for a
        // bottle still in the grid, and the first row of the list is whatever
        // the sort puts there.
        try app.buttons["wine-detail-menu"].firstMatch.waitOrFail()
        save("wine-detail")
        // The detail is a sheet, dismissed by dragging it down rather than by
        // its close button, whose label is a translated word. The drag starts
        // near the top: a swipe from mid-screen scrolls the sheet's content
        // instead of moving the sheet, and the tab bar stays out of reach.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))

        try open("scan", at: 3)
        try app.buttons["scan-photo-picker"].waitOrFail()
        save("scan")

        try app.buttons["scan-photo-picker"].tapOrFail()
        // The stubbed scan still goes to the server and back; the review form is
        // there once its name field is.
        try app.textFields["review-name-field"].waitOrFail(timeout: 60)
        save("scan-review")
    }

    /// Writes straight into the working copy through `#filePath`. That ties the
    /// capture to a simulator running on the machine that holds the repository,
    /// which is the only place it is ever run: a device would write nowhere.
    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let directory = repositoryRoot
            .appendingPathComponent("screenshots")
            .appendingPathComponent(subdirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Failed to save screenshot '\(name)' to \(directory.path): \(error)")
        }
        // Also attached to the result bundle: when a run is inspected after the
        // fact, the picture is in there rather than only on the disk it wrote to.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The App Store locales the app ships in, mapped to what iOS expects.
    private func locale(for language: String) -> String {
        switch language {
        case "en": return "en_US"
        case "de": return "de_DE"
        case "es": return "es_ES"
        case "it": return "it_IT"
        case "pt": return "pt_PT"
        case "ja": return "ja_JP"
        default: return "fr_FR"
        }
    }
}
