import Foundation

/// Builds the shareable artefacts for a household invitation code: the universal
/// link a guest opens to join, and the e-mail subject/body wrapped around it.
enum InvitationLink {
    /// Host serving the invitation universal link + AASA (the Firebase Hosting
    /// default domain). Kept in sync with the `applinks:` entitlement and the
    /// deep-link host check in `AuthRoot`.
    static let host = "vinarium-prod.web.app"

    /// Custom URL scheme the invitation web page uses to reopen the installed app
    /// (`vinarium://rejoindre/<CODE>`) when the universal link can't re-trigger from
    /// that page. Declared in `Info.plist` (`CFBundleURLSchemes`) and handled in
    /// `AuthRoot`.
    static let scheme = "vinarium"

    /// The universal link that opens the app on `/rejoindre/<CODE>` (and falls back
    /// to the web landing page when the app is not installed).
    static func url(code: String) -> URL {
        // The code alphabet is URL-safe (A–Z, 2–9), so no escaping is needed.
        URL(string: "https://\(host)/rejoindre/\(code)")!
    }

    static var mailSubject: String { String(localized: "Rejoins ma cave sur Vinarium") }

    /// The invitation body used for the mail draft, carrying both the tap-to-join
    /// link and the raw code for anyone who prefers to type it in the app.
    static func mailBody(code: String) -> String {
        String(
            localized: """
                Rejoins ma cave sur Vinarium.

                Ouvre ce lien depuis ton iPhone :
                \(url(code: code).absoluteString)

                Ou saisis ce code dans l'app : \(code)
                """
        )
    }
}
