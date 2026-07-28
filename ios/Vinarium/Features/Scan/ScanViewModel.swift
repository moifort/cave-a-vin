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

/// État complet de la fiche au moment de valider, plus le choix de la popup.
/// Le vin porte les champs scalaires (dont `giftedBy`) ; la dégustation et le
/// conseil sont persistés séparément selon ce qui est rempli.
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
    /// L'analyse IA est en cours : la sheet du flux affiche l'orbe, caméra coupée.
    /// Vraie tant que la photo se charge et que l'IA répond.
    var isAnalyzing = false
    /// L'IA n'a rien reconnu sur la photo : la sheet du flux reste ouverte et
    /// affiche le message « aucune étiquette détectée » (phase interne, pas une
    /// seconde sheet), pour éviter un fondu fermeture puis réouverture.
    var scanNotRecognized = false
    /// L'allocation de scans du mois est épuisée : le flux retombe sur la caméra
    /// et le paywall se présente par-dessus, plutôt qu'une alerte d'erreur.
    var paywallShown = false
    /// Le paywall à présenter une fois la sheet du flux fermée. Présenter une
    /// sheet pendant qu'une autre se ferme échoue, donc on diffère au `onDismiss`.
    private var pendingPaywall = false
    var isSaving = false
    var pendingLocation: DiscoveryLocationDraft?
    /// Vin déjà créé pendant cette session de review : si une écriture
    /// post-création (dégustation / conseil) échoue, un nouveau clic ne recrée
    /// pas un doublon — on réutilise le vin existant.
    private var createdWine: Wine?

    func capturePhoto(_ imageData: Data) {
        isAnalyzing = true
        scanNotRecognized = false
        error = nil

        Task {
            do {
                let result = try await WineAPI.scan(imageData: imageData)
                if result.recognized {
                    // Dans la sheet du flux, l'overlay d'analyse se fond pour
                    // révéler la review : la sheet reste ouverte (étape ≠ caméra).
                    self.step = .review(result, imageData)
                    self.isAnalyzing = false
                } else {
                    // La sheet reste ouverte et bascule sur le message d'erreur.
                    self.scanNotRecognized = true
                    self.isAnalyzing = false
                }
            } catch let apiError as APIError where apiError.domainCode == "QUOTA_EXHAUSTED" {
                // Ce n'est pas une panne : c'est l'offre qui s'arrête là. La sheet
                // du flux se ferme, puis le paywall se présente au `onDismiss`.
                print("DEBUG-TEMP catch quota -> pendingPaywall = true")
                self.pendingPaywall = true
                self.isAnalyzing = false
            } catch {
                self.error = reportError(error)
                self.isAnalyzing = false
            }
        }
    }

    /// Quitte la phase « rien trouvé » : referme la sheet du flux et ramène sur la
    /// caméra pour reprendre une photo.
    func dismissNotRecognized() {
        scanNotRecognized = false
    }

    /// Présente le paywall différé une fois la sheet du flux totalement fermée.
    func flushPendingOutcome() {
        guard pendingPaywall else { return }
        pendingPaywall = false
        paywallShown = true
    }

    /// Vrai dès qu'on a dépassé la caméra : la sheet du flux (analyse, rien trouvé,
    /// review, placement, confirmation) est alors présentée par-dessus la caméra.
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
            // Réutilise le vin déjà créé si un retry suit un échec post-création.
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
                // L'écran de fin reflète ce que la fiche portait (favori / conseil),
                // plus un choix de popup : il oriente la liste vers la bonne vue.
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

    /// Enregistre une note de dégustation si la fiche en porte une : coup de cœur
    /// explicite, note en étoiles ou commentaires/contacts.
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

    /// Enregistre un conseil si un « conseillé par » ou un commentaire est renseigné.
    private func persistRecommendation(for wineId: String, _ s: ScanSubmission) async throws {
        let (name, comment) = recommendationFields(s)
        guard name != nil || comment != nil else { return }
        try await RecommendationAPI.create(wineId: wineId, recommenderName: name, comment: comment)
    }

    /// La fiche porte-t-elle un conseil (nom ou commentaire) ?
    private func hasRecommendation(_ s: ScanSubmission) -> Bool {
        let (name, comment) = recommendationFields(s)
        return name != nil || comment != nil
    }

    /// Source unique des champs conseil normalisés : l'écran de fin et la
    /// persistance doivent voir exactement la même chose.
    private func recommendationFields(_ s: ScanSubmission) -> (name: String?, comment: String?) {
        (
            s.recommenderName?.isEmpty == false ? s.recommenderName : nil,
            s.recommendationComment?.isEmpty == false ? s.recommendationComment : nil
        )
    }

    func reset() {
        step = .camera
        error = nil
        isAnalyzing = false
        scanNotRecognized = false
        paywallShown = false
        pendingPaywall = false
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
