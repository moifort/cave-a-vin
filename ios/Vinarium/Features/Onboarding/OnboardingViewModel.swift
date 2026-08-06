import Observation
import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    var firstName = ""
    var choice: PresetChoice?
    var rows = 6
    var cols = 8
    var zones = 1

    private(set) var isSubmitting = false
    var error: String?

    var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        !trimmedFirstName.isEmpty
            && (1...OnboardingLimits.maxRows).contains(rows)
            && (1...OnboardingLimits.maxCols).contains(cols)
            && (1...OnboardingLimits.maxZones).contains(zones)
    }

    var capacity: Int { rows * cols }

    /// Record the dimensioning choice and pre-fill the dimensions from it.
    func select(_ choice: PresetChoice) {
        self.choice = choice
        if case .preset(let preset) = choice {
            let grid = preset.defaultGrid()
            rows = min(grid.rows, OnboardingLimits.maxRows)
            cols = min(grid.cols, OnboardingLimits.maxCols)
            zones = min(preset.zones, OnboardingLimits.maxZones)
        }
    }

    /// Persist the profile and cellar dimensions. Returns true on success so the
    /// coordinator can hand control back to the auth gate.
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        error = nil
        do {
            try await OnboardingAPI.completeOnboarding(
                firstName: trimmedFirstName,
                rows: rows,
                cols: cols,
                zones: zones
            )
            // Only a completion the server acknowledged counts: this is the step
            // the whole activation funnel is measured against.
            track(
                .onboardingCompleted(
                    rows: rows,
                    cols: cols,
                    fromPreset: { if case .preset = choice { true } else { false } }()
                )
            )
            isSubmitting = false
            return true
        } catch {
            self.error = reportError(error)
            isSubmitting = false
            return false
        }
    }
}
