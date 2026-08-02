import Foundation
import SwiftUI

enum ScanStep {
    case camera
    case review(ScanResult, Data)
    case placing(id: String, name: String, beverageType: BeverageType, color: WineColor?, vintage: Int?)
    case confirmed(name: String, beverageType: BeverageType, color: WineColor?, position: String)
    case favoriteSaved
    case recommendationSaved
    case saved
}

/// The full state of the form at submit time, plus the destination picked in the
/// popup. The wine carries the scalar fields (`giftedBy` included); the tasting and
/// the recommendation are persisted separately, depending on what was filled in.
struct ScanSubmission {
    let request: CreateWineRequest
    let choice: ScanDestination
    let favorite: Bool
    let rating: Int
    let tastingDate: Date
    let contacts: [String]
    let tastingNotes: String?
    let recommenderName: String?
    let recommendationComment: String?
}

@MainActor @Observable
final class ScanViewModel {
    var step: ScanStep = .camera
    var error: String?
    /// The AI analysis is running: the flow sheet shows the orb and the camera is off.
    /// True while the photo loads and until the AI answers.
    var isAnalyzing = false
    /// The AI recognized nothing on the photo: the flow sheet stays open and shows
    /// the "no label detected" message (an inner phase, not a second sheet), which
    /// avoids a close-then-reopen fade.
    var scanNotRecognized = false
    /// The monthly scan allowance is exhausted: the flow falls back to the camera
    /// and the paywall is presented on top, rather than an error alert.
    var paywallShown = false
    /// The paywall to present once the flow sheet is closed. Presenting a sheet
    /// while another one is dismissing fails, so it is deferred to `onDismiss`.
    private var pendingPaywall = false
    var isSaving = false
    var pendingLocation: DiscoveryLocationDraft?
    /// Wine already created during this review session: if a post-creation write
    /// (tasting / recommendation) fails, tapping again does not create a duplicate,
    /// the existing wine is reused.
    private var createdWine: Wine?

    func capturePhoto(_ imageData: Data) {
        isAnalyzing = true
        scanNotRecognized = false
        error = nil

        Task {
            do {
                let result = try await WineAPI.scan(imageData: imageData)
                if result.recognized {
                    // Inside the flow sheet, the analysis overlay fades out to reveal
                    // the review: the sheet stays open (step is no longer the camera).
                    self.step = .review(result, imageData)
                    self.isAnalyzing = false
                } else {
                    // The sheet stays open and switches to the error message.
                    self.scanNotRecognized = true
                    self.isAnalyzing = false
                }
            } catch let apiError as APIError where apiError.domainCode == "QUOTA_EXHAUSTED" {
                // This is not a failure, it is where the plan stops. The flow sheet
                // closes, then the paywall is presented from `onDismiss`.
                self.pendingPaywall = true
                self.isAnalyzing = false
            } catch {
                self.error = reportError(error)
                self.isAnalyzing = false
            }
        }
    }

    /// Leaves the "nothing found" phase: closes the flow sheet and goes back to the
    /// camera so another photo can be taken.
    func dismissNotRecognized() {
        scanNotRecognized = false
    }

    /// Presents the deferred paywall once the flow sheet is fully dismissed.
    func flushPendingOutcome() {
        guard pendingPaywall else { return }
        pendingPaywall = false
        paywallShown = true
    }

    /// True as soon as the camera step is left behind: the flow sheet (analysis,
    /// nothing found, review, placement, confirmation) is then presented over the camera.
    var isFlowActive: Bool {
        if isAnalyzing || scanNotRecognized { return true }
        if case .camera = step { return false }
        return true
    }

    /// The camera only streams on the camera step, outside of any flow: once a
    /// photo is taken the stream is closed, and it opens again on the way back.
    var isCameraLive: Bool {
        !isFlowActive && !paywallShown
    }

    func attachLocation(_ draft: DiscoveryLocationDraft?) {
        pendingLocation = draft
    }

    func resolvePendingPlaceName() async {
        guard let location = pendingLocation, location.placeName == nil else { return }
        let name = await PlaceNameResolver.resolve(location.coordinate)
        if name != nil, var current = pendingLocation,
           current.latitude == location.latitude, current.longitude == location.longitude {
            current.placeName = name
            pendingLocation = current
        }
    }

    func submit(_ submission: ScanSubmission) async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            // Reuse the wine already created when a retry follows a post-creation failure.
            let wine: Wine
            if let existing = createdWine {
                wine = existing
            } else {
                wine = try await WineAPI.create(submission.request)
                createdWine = wine
            }
            try await persistTasting(for: wine.id, submission)
            try await persistRecommendation(for: wine.id, submission)

            switch submission.choice {
            case .cellar:
                step = .placing(
                    id: wine.id,
                    name: wine.name,
                    beverageType: wine.beverageType,
                    color: wine.color,
                    vintage: wine.vintage
                )
            case .justSave:
                // The closing screen reflects what the form carried (favorite /
                // recommendation) rather than the popup choice: it points the list
                // at the right view.
                if submission.favorite {
                    step = .favoriteSaved
                } else if hasRecommendation(submission) {
                    step = .recommendationSaved
                } else {
                    step = .saved
                }
            }
        } catch {
            self.error = reportError(error)
        }
    }

    /// Records a tasting note when the form carries one: an explicit favorite, a star
    /// rating, or notes/contacts.
    private func persistTasting(for wineId: String, _ s: ScanSubmission) async throws {
        let markFavorite = s.favorite
        let hasTastingDetails = s.rating > 0 || s.tastingNotes != nil || !s.contacts.isEmpty
        guard markFavorite || hasTastingDetails else { return }

        let formatter = ISO8601DateFormatter()
        try await WineAPI.recordTasting(
            id: wineId,
            consumedDate: formatter.string(from: s.tastingDate),
            rating: s.rating == 0 ? nil : s.rating,
            contacts: s.contacts.isEmpty ? nil : s.contacts,
            tastingNotes: s.tastingNotes,
            favorite: markFavorite ? true : nil
        )
    }

    /// Records a recommendation when a recommender name or a comment was filled in.
    private func persistRecommendation(for wineId: String, _ s: ScanSubmission) async throws {
        let (name, comment) = recommendationFields(s)
        guard name != nil || comment != nil else { return }
        try await RecommendationAPI.create(wineId: wineId, recommenderName: name, comment: comment)
    }

    /// Does the form carry a recommendation (a name or a comment)?
    private func hasRecommendation(_ s: ScanSubmission) -> Bool {
        let (name, comment) = recommendationFields(s)
        return name != nil || comment != nil
    }

    /// Single source for the normalized recommendation fields: the closing screen and
    /// the persistence step must see exactly the same thing.
    private func recommendationFields(_ s: ScanSubmission) -> (name: String?, comment: String?) {
        (
            s.recommenderName?.isEmpty == false ? s.recommenderName : nil,
            s.recommendationComment?.isEmpty == false ? s.recommendationComment : nil
        )
    }

    /// Back to the camera, flow state cleared. The pending outcome is not flow
    /// state and deliberately survives: SwiftUI writes `false` into the flow
    /// sheet's binding while it closes, which lands here *before* `onDismiss`, so
    /// clearing the paywall here would erase the very thing that closed the sheet.
    func reset() {
        step = .camera
        error = nil
        isAnalyzing = false
        scanNotRecognized = false
        pendingLocation = nil
        createdWine = nil
    }
}

extension ScanStep: Equatable {
    static func == (lhs: ScanStep, rhs: ScanStep) -> Bool {
        switch (lhs, rhs) {
        case (.camera, .camera), (.favoriteSaved, .favoriteSaved), (.recommendationSaved, .recommendationSaved), (.saved, .saved): return true
        case (.review, .review), (.placing, .placing), (.confirmed, .confirmed): return true
        default: return false
        }
    }
}
