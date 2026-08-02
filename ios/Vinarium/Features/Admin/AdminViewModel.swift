import SwiftUI

/// Loads the admin metrics. Shared between the banner and the Admin screen so that
/// opening the sheet does not fire a call the banner already displays.
@MainActor @Observable
final class AdminViewModel {
    private(set) var metrics: AdminMetrics?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            metrics = try await AdminAPI.metrics()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
