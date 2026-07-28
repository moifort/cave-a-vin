import CoreLocation
import PhotosUI
import SwiftUI

enum ScanFlowResult {
    case addedToCellar
    case addedToFavorites
    case addedToRecommendations
    case added
}

struct ScanView: View {
    var onFlowCompleted: (ScanFlowResult) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ScanViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shouldCapture = false

    private var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestPhoto")
    }

    var body: some View {
        cameraScreen
            .sheet(isPresented: flowPresented, onDismiss: viewModel.flushPendingOutcome) {
                flowSheet
            }
            .sheet(isPresented: $viewModel.paywallShown) {
                PremiumSheet(trigger: .scanAllowanceSpent)
            }
            .onChange(of: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                selectedPhoto = nil
                // Ouvre la sheet du flux tout de suite (sur l'étape d'analyse), le
                // temps de charger et redimensionner l'image avant de lancer le scan.
                viewModel.isAnalyzing = true
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        viewModel.isAnalyzing = false
                        return
                    }
                    attachLocationFromExif(in: data)
                    let jpeg = await Task.detached(priority: .userInitiated) {
                        UIImage(data: data).flatMap { $0.resized(maxDimension: 800).jpegData(compressionQuality: 0.6) }
                    }.value
                    if let jpeg {
                        viewModel.capturePhoto(jpeg)
                    } else {
                        viewModel.isAnalyzing = false
                    }
                }
            }
            .alert("Erreur", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
    }

    // MARK: - Camera

    /// Base permanente du plein écran : l'aperçu caméra et ses contrôles. Le reste
    /// du flux (analyse, review, placement, confirmation) se présente en sheet
    /// par-dessus.
    private var cameraScreen: some View {
        ZStack {
            if viewModel.isCameraLive {
                liveCamera
            } else {
                // The camera is closed as soon as the shot leaves for analysis: the
                // rest of the flow runs over a neutral background, not over a preview
                // that would hold the hardware for nothing.
                Color.black.ignoresSafeArea()
            }
        }
    }

    private var liveCamera: some View {
        ZStack {
            CameraView(onCapture: { data in
                viewModel.capturePhoto(data)
                captureCurrentLocation()
            }, shouldCapture: $shouldCapture)
                .ignoresSafeArea()

            ViewfinderOverlay()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                    .accessibilityIdentifier("scan-close-button")
                    Spacer()
                }
                .padding()
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    if isUITest {
                        Button {
                            loadTestImage()
                        } label: {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.ultraThinMaterial, in: .circle)
                        }
                        .accessibilityIdentifier("scan-photo-picker")
                    } else {
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images
                        ) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.ultraThinMaterial, in: .circle)
                        }
                        .accessibilityIdentifier("scan-photo-picker")
                    }
                    Spacer()
                    Button {
                        shouldCapture = true
                    } label: {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .accessibilityIdentifier("scan-capture-button")
                    Spacer()
                    Color.clear.frame(width: 56, height: 56)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Flow sheet

    /// La sheet présentée dès qu'un scan démarre. Un `NavigationStack` unique
    /// enchaîne review → placement → confirmation par fondu, et l'étape d'analyse
    /// est un overlay plein cadre par-dessus tant que l'IA travaille. Fermer /
    /// annuler retombe sur la caméra ; la fermeture n'est jamais accidentelle
    /// (swipe désactivé), seuls les boutons pilotent le flux.
    private var flowSheet: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    if viewModel.scanNotRecognized {
                        ScanNoResultPage(onClose: { viewModel.dismissNotRecognized() })
                            .transition(.opacity)
                    } else {
                        stepContent
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.step)
                .animation(.easeInOut(duration: 0.35), value: viewModel.scanNotRecognized)
            }

            if viewModel.isAnalyzing {
                ScanAnalyzingPage()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isAnalyzing)
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .camera:
            // Sous l'overlay d'analyse au démarrage du flux : rien à montrer.
            Color.clear

        case .review(let result, let imageData):
            ScanReviewPage(
                scanResult: result,
                imageData: imageData,
                isSaving: viewModel.isSaving,
                initialLocation: viewModel.pendingLocation,
                onSubmit: { submission in await viewModel.submit(submission) },
                onCancel: { viewModel.reset() }
            )
            .transition(.opacity)

        case .placing(let id, let name, let beverageType, let color, let vintage):
            CellarPlacementView(
                wineId: id,
                wineName: name,
                beverageType: beverageType,
                wineColor: color,
                wineVintage: vintage,
                onCancel: {
                    viewModel.reset()
                }
            ) { position in
                viewModel.step = .confirmed(
                    name: name,
                    beverageType: beverageType,
                    color: color,
                    position: position
                )
            }
            .transition(.opacity)

        case .confirmed(let name, let beverageType, let color, let position):
            ScanConfirmationPage(
                wineName: name,
                beverageType: beverageType,
                wineColor: color,
                position: position
            ) {
                viewModel.reset()
                onFlowCompleted(.addedToCellar)
            }
            .transition(.opacity)

        case .favoriteSaved:
            Color.clear
                .onAppear {
                    viewModel.reset()
                    onFlowCompleted(.addedToFavorites)
                }

        case .recommendationSaved:
            Color.clear
                .onAppear {
                    viewModel.reset()
                    onFlowCompleted(.addedToRecommendations)
                }

        case .saved:
            Color.clear
                .onAppear {
                    viewModel.reset()
                    onFlowCompleted(.added)
                }
        }
    }

    /// La sheet du flux est ouverte tant qu'on a dépassé la caméra (analyse en
    /// cours ou étape review/placement/confirmation). Un dismiss programmatique
    /// (retour à `.camera`) la referme ; le setter retombe proprement sur la caméra.
    private var flowPresented: Binding<Bool> {
        Binding(
            get: { viewModel.isFlowActive },
            set: { if !$0 { viewModel.reset() } }
        )
    }

    // MARK: - Location

    private func captureCurrentLocation() {
        Task {
            guard let coordinate = await LocationService.shared.requestCurrentCoordinate() else { return }
            attachLocation(coordinate)
        }
    }

    private func attachLocationFromExif(in data: Data) {
        guard let coordinate = PhotoLocationExtractor.extract(from: data) else { return }
        attachLocation(coordinate)
    }

    private func attachLocation(_ coordinate: CLLocationCoordinate2D) {
        viewModel.attachLocation(
            DiscoveryLocationDraft(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                placeName: nil
            )
        )
        Task { await viewModel.resolvePendingPlaceName() }
    }

    private func loadTestImage() {
        Task {
            let jpeg = await Task.detached(priority: .userInitiated) {
                guard let url = Bundle.main.url(forResource: "etiquette", withExtension: "jpg"),
                      let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else { return nil as Data? }
                return image.resized(maxDimension: 800).jpegData(compressionQuality: 0.6)
            }.value
            guard let jpeg else { return }
            viewModel.capturePhoto(jpeg)
        }
    }
}
