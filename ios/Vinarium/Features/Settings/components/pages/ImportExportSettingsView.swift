import SwiftUI
import UniformTypeIdentifiers

struct ImportExportSettingsView: View {
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingExport: ExportDocument?
    @State private var pendingImportURL: URL?
    @State private var status: String?
    @State private var error: String?
    @State private var isWorking = false
    @State private var showImportConfirm = false

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await prepareExport() }
                } label: {
                    Label("Exporter mes données", systemImage: "square.and.arrow.up")
                }
                .disabled(isWorking)
            } header: {
                Text("Exporter")
            } footer: {
                Text("Génère un fichier JSON contenant l'ensemble de tes vins, placements en cave, dégustations, recommandations, cadeaux et historique.")
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label("Importer un fichier JSON", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } header: {
                Text("Importer")
            } footer: {
                Text("Remplace l'intégralité de tes données par celles du fichier sélectionné. Cette action est irréversible.")
            }

            if let status {
                Section { Text(status).foregroundStyle(.green) }
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            if isWorking {
                Section { ProgressView() }
            }
        }
        .navigationTitle("Importer / Exporter")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting,
            document: pendingExport,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success: status = String(localized: "Export terminé.")
            case .failure(let err): error = err.localizedDescription
            }
            pendingExport = nil
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showImportConfirm = true
            case .failure(let err):
                error = err.localizedDescription
            }
        }
        .alert("Confirmer l'import", isPresented: $showImportConfirm, presenting: pendingImportURL) { url in
            Button("Annuler", role: .cancel) { pendingImportURL = nil }
            Button("Remplacer", role: .destructive) {
                Task { await runImport(url: url) }
            }
        } message: { _ in
            Text("L'import remplace l'ensemble de tes données par celles du fichier. Continuer ?")
        }
    }

    private var defaultFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "vinarium-\(formatter.string(from: Date()))"
    }

    private func prepareExport() async {
        isWorking = true
        defer { isWorking = false }
        error = nil
        status = nil
        do {
            let payload = try await SettingsAPI.exportData()
            guard let data = payload.data(using: .utf8) else {
                error = String(localized: "Encodage invalide.")
                return
            }
            pendingExport = ExportDocument(data: data)
            isExporting = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func runImport(url: URL) async {
        isWorking = true
        defer { isWorking = false }
        error = nil
        status = nil
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            guard let payload = String(data: raw, encoding: .utf8) else {
                error = String(localized: "Fichier illisible.")
                return
            }
            let summary = try await SettingsAPI.importData(payload: payload)
            status = String(localized: "Import terminé : \(summary.totalRecords) éléments restaurés.")
            NotificationCenter.default.post(name: .vinariumDataDidReload, object: nil)
        } catch {
            self.error = error.localizedDescription
        }
        pendingImportURL = nil
    }
}

extension Notification.Name {
    static let vinariumDataDidReload = Notification.Name("VinariumDataDidReload")
}

private struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    static let writableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        ImportExportSettingsView()
    }
}
