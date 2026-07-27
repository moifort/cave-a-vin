import SwiftUI

struct AsyncToolbarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () async -> Void

    @State private var isInProgress = false

    var body: some View {
        Button(role: role) {
            guard !isInProgress else { return }
            isInProgress = true
            Task {
                await action()
                isInProgress = false
            }
        } label: {
            if isInProgress {
                ProgressView()
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .labelStyle(.iconOnly)
        .disabled(isInProgress)
    }
}
