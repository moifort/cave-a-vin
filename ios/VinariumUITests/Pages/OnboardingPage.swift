import XCTest

/// The first-launch wizard. Every end-to-end run signs in with a brand new
/// account, so it always starts here: welcome → prénom → cellar choice →
/// dimensions → summary.
@MainActor
struct OnboardingPage {
    let app: XCUIApplication

    @discardableResult
    func verify() throws -> Self {
        // The account is created and signed in while the app launches, so the
        // first screen takes a round-trip longer than a plain view transition.
        try app.buttons["onboarding-start"].waitOrFail(timeout: 30, "Onboarding never appeared — sign-in probably failed")
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
        // the app hands over, so this waits on a round-trip, not a transition.
        try app.navigationBars["Accueil"].waitOrFail(timeout: 20, "Onboarding did not hand over to the app")
        return DashboardPage(app: app)
    }
}
