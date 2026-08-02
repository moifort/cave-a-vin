import XCTest

/// The first-launch wizard. Every end-to-end run signs in with a brand new
/// account, so it always starts here: welcome → first name → cellar choice →
/// dimensions → summary.
@MainActor
struct OnboardingPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        // The account is created and signed in while the app launches, so the
        // first screen takes a round-trip longer than a plain view transition.
        // The very first scenario of a run pays for cold emulators on top: the
        // Firestore one boots a JVM that CI has just downloaded, and 30s was not
        // enough there — the app sat on its loading state and the whole gate
        // failed. Waiting is condition-based, so a warm run is not slowed down.
        try app.buttons["onboarding-start"].waitOrFail(timeout: 90, "Onboarding never appeared — sign-in probably failed")
        return self
    }

    /// Walks the whole wizard with the default 6 × 8 grid, which is what the
    /// rest of the scenario places bottles into.
    func complete(firstName: String) throws -> DashboardPage {
        try app.buttons["onboarding-start"].tapOrFail()

        let nameField = try app.textFields["onboarding-firstname-field"].waitOrFail()
        nameField.tap()
        nameField.typeText(firstName)
        try app.buttons["onboarding-firstname-next"].tapOrFail()

        // "Sur mesure" keeps the default dimensions rather than depending on a
        // catalog entry that may be renamed or dropped.
        try app.buttons["onboarding-preset-custom"].tapOrFail()
        try app.buttons["onboarding-dimensions-next"].tapOrFail()
        try app.buttons["onboarding-finish"].tapOrFail()

        // completeOnboarding writes the profile and provisions the grid before
        // the app hands over, so this waits on the heaviest round-trip of the
        // run, not a transition. 20s held on the dev Mac and timed out on CI.
        try app.navigationBars["Home"].waitOrFail(timeout: 60, "Onboarding did not hand over to the app")
        return DashboardPage(app: app)
    }
}
