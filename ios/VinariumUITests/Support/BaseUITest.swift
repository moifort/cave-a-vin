import XCTest

struct UITestFailure: Error {
    let message: String
}

extension XCUIElement {
    @discardableResult
    func waitOrFail(timeout: TimeInterval = 4, _ message: String? = nil, file: StaticString = #file, line: UInt = #line) throws -> XCUIElement {
        guard self.waitForExistence(timeout: timeout) else {
            let msg = message ?? "Element \(self) not found"
            XCTFail(msg, file: file, line: line)
            throw UITestFailure(message: msg)
        }
        return self
    }

    func tapOrFail(timeout: TimeInterval = 4, file: StaticString = #file, line: UInt = #line) throws {
        try waitOrFail(timeout: timeout, file: file, line: line)
        self.tap()
    }
}

extension XCUIApplication {
    /// Scrolls down until `element` is reachable. A SwiftUI `Form` only
    /// materializes the rows it renders, so a field further down the page does
    /// not exist in the accessibility tree until it is scrolled into view.
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return true }
            swipeUp()
        }
        return element.exists && element.isHittable
    }
}

/// Launches the app against the local end-to-end stack: the Nitro server on
/// :3000, backed by the Firebase emulators (`scripts/e2e.sh` starts all of it).
///
/// Isolation comes from two places and needs no server-side reset endpoint: the
/// emulators start empty on every run, and each test signs in with an account of
/// its own, so a test always finds an empty cellar and an untouched quota.
@MainActor
class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    /// The account this test runs as. Unique per test so two tests in the same
    /// run never share a cellar.
    private(set) var account: String!

    override func setUp() async throws {
        continueAfterFailure = false
        account = "e2e-\(UUID().uuidString.lowercased())@vinarium.test"
        app = XCUIApplication()
        app.launchArguments = [
            // Read by APIClient through UserDefaults (NSArgumentDomain).
            "-serverURL", "http://127.0.0.1:3000",
            // Read by UITestEnvironment (DEBUG only): points Firebase Auth at the
            // emulator and signs in, since Sign in with Apple cannot be driven.
            "-uiTestAuthEmulator", "127.0.0.1:9099",
            "-uiTestAccount", account,
            // Replaces the camera with the bundled test label.
            "-UITestPhoto",
        ]
        app.launch()

        // A brand new account always lands on the setup wizard, so every test
        // walks it before reaching its own scenario. It doubles as the check
        // that sign-in worked and that the cellar grid got provisioned.
        _ = try OnboardingPage(app: app).verify().complete(firstName: "Thibaut")
    }

    override func tearDown() async throws {
        app.terminate()
    }
}
