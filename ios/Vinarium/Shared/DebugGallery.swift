#if DEBUG
import SwiftUI

/// A DEBUG-only list of screens that are hard to reach in a live session,
/// shown instead of the app when it is launched with `-debugGallery`. It lets
/// a screen be displayed on a simulator with no signed-in account, e.g. from
/// `xcrun simctl launch booted com.polyforms.vinarium.app -debugGallery`.
struct DebugGallery: View {
    @State private var paywallTrigger: PremiumTrigger?

    var body: some View {
        NavigationStack {
            List {
                Section("Abonnement") {
                    Button("Paywall, découverte") { paywallTrigger = .discover }
                    Button("Paywall, scans épuisés") { paywallTrigger = .scanAllowanceSpent }
                }
                Section("Chargement") {
                    NavigationLink("Verre de vin (premier chargement)") {
                        LoadingStateView()
                    }
                }
            }
            .navigationTitle("Debug")
        }
        .sheet(item: $paywallTrigger) { trigger in
            PremiumSheet(trigger: trigger)
                .environment(SubscriptionStore())
        }
    }
}

/// `sheet(item:)` needs an identity; the case name is one.
extension PremiumTrigger: Identifiable {
    var id: String { String(describing: self) }
}

#Preview {
    DebugGallery()
}
#endif
