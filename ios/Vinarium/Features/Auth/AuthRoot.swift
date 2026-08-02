import FirebaseCore
import SwiftUI

/// Top-level gate: shows the blocking update screen when the backend no longer
/// supports this build; otherwise LoginView when no Firebase user is signed in; once signed
/// in, reads the onboarding state and shows the wizard until it is completed,
/// otherwise the main TabView (`ContentView`). Also catches invitation links, both
/// the universal link (`https://vinarium-prod.web.app/rejoindre/<CODE>`) and the
/// custom scheme (`vinarium://rejoindre/<CODE>`), and presents the join sheet.
struct AuthRoot: View {
    @State private var session = AuthSession()
    @State private var gate = OnboardingGate()
    @State private var supportGate = AppSupportGate()
    /// App-scoped: it listens to `Transaction.updates` for the whole lifetime of
    /// the app, so a renewal landing mid-session is picked up wherever the user is.
    @State private var subscriptions = SubscriptionStore()
    @Environment(\.scenePhase) private var scenePhase

    /// A pending invitation code, kept until the app is ready to present the join
    /// sheet (a link opened while signed out surfaces after sign-in + onboarding).
    /// `ContentView` owns the presentation so it can refresh the shared cave on join.
    @State private var joinRequest: HouseholdJoinRequest?

    var body: some View {
        Group {
            if case .updateRequired(let appStoreURL) = supportGate.state {
                UpdateRequiredView(appStoreURL: appStoreURL)
            } else if session.user == nil {
                LoginView()
            } else {
                signedIn
            }
        }
        .environment(session)
        .environment(subscriptions)
        .environment(\.isAdmin, gate.isAdmin)
        .task { await supportGate.check() }
        .task(id: session.user?.uid) {
            // The plan is the server's answer, and it needs a signed-in caller.
            if session.user != nil { await subscriptions.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await supportGate.check() } }
        }
        .task(id: session.user?.uid) {
            if session.user != nil {
                await gate.refresh()
            } else {
                gate.reset()
            }
        }
        .onOpenURL { url in
            if let code = Self.joinCode(from: url) {
                joinRequest = HouseholdJoinRequest(code: code)
            }
        }
    }

    @ViewBuilder
    private var signedIn: some View {
        switch gate.state {
        case .loading:
            LoadingStateView()
        case .required:
            OnboardingView(onCompleted: { gate.markCompleted() })
        case .ready:
            ContentView(joinRequest: $joinRequest)
        case .failed(let message):
            ContentUnavailableView {
                Label("Connexion impossible", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Réessayer") { Task { await gate.refresh() } }
            }
        }
    }

    /// Extracts an invitation code from either the universal link
    /// (`https://<host>/rejoindre/<CODE>`) or the custom scheme
    /// (`vinarium://rejoindre/<CODE>`, the web page's "open in app" fallback).
    private static func joinCode(from url: URL) -> String? {
        // Custom scheme: "rejoindre" is the host, the code the single path segment.
        if url.scheme == InvitationLink.scheme {
            guard url.host == "rejoindre" else { return nil }
            let code = url.pathComponents.filter { $0 != "/" }.first?.uppercased() ?? ""
            return code.isEmpty ? nil : code
        }
        // Universal link: "rejoindre" and the code are both path segments.
        guard url.host == InvitationLink.host else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "rejoindre" else { return nil }
        let code = parts[1].uppercased()
        return code.isEmpty ? nil : code
    }
}

#Preview {
    // `AuthSession` reads `Auth.auth()` on init, which traps when Firebase was
    // never configured: the canvas does not run `VinariumApp.init`, so the gate
    // configures it here. With no session in the simulator this lands on the
    // login screen, which is the only state the canvas can reach on its own.
    if FirebaseApp.app() == nil { FirebaseApp.configure() }
    return AuthRoot()
}
