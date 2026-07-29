import FirebaseCore
import Sentry
import SwiftUI

@main
struct VinariumApp: App {
    init() {
        FirebaseApp.configure()
        #if DEBUG
        // Points Auth at the local emulator and signs in, but only when the UI
        // test launch arguments are there. A normal Debug run is untouched.
        UITestEnvironment.bootstrapIfNeeded()
        #endif
        startSentry()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // The gallery bypasses sign-in on purpose: it exists to show a
            // screen on a simulator that has no session, e.g. from simctl.
            if ProcessInfo.processInfo.arguments.contains("-debugGallery") {
                DebugGallery()
            } else {
                AuthRoot()
            }
            #else
            AuthRoot()
            #endif
        }
    }

    private func startSentry() {
        #if DEBUG
        // Dev builds (Debug config = Xcode run / simulator) never start Sentry, so
        // their noise — e.g. simulator App Hangs — stays out of the production
        // project. Distribution builds (App Store / TestFlight, archived in Release)
        // compile the branch below and keep reporting.
        #else
        let dsn = Secrets.sentryDsn
        if dsn.isEmpty { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.tracesSampleRate = 1.0
            options.enableAutoSessionTracking = true
            options.enableTimeToFullDisplayTracing = true
            options.tracePropagationTargets = []
        }
        #endif
    }
}
