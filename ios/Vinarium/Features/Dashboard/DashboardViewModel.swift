import Foundation

@MainActor @Observable
final class DashboardViewModel {
    var data: DashboardData?
    var isLoading = false
    var error: String?

    /// A cellar worth opening the app for. Below this the app is a form that was
    /// filled in once; above it, it is being used.
    private static let stockedThreshold = 10

    func load() async {
        isLoading = true
        error = nil
        do {
            let loaded = try await DashboardAPI.getData()
            data = loaded
            if loaded.bottleCount >= Self.stockedThreshold {
                trackOnce(.cellarStocked(bottles: loaded.bottleCount))
            }
        } catch {
            self.error = reportError(error)
        }
        isLoading = false
    }
}
