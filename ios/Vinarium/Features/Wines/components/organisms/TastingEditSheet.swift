import SwiftUI

/// Edits the score and the comment of an already recorded tasting note.
struct TastingEditSheet: View {
    let initialRating: Int?
    let initialNotes: String?
    /// (rating, notes) — rating is 0 when the wine was never scored, notes is
    /// empty when the comment was cleared.
    let onConfirm: (Int, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int
    @State private var tastingNotes: String

    init(
        initialRating: Int?,
        initialNotes: String?,
        onConfirm: @escaping (Int, String) async -> Void
    ) {
        self.initialRating = initialRating
        self.initialNotes = initialNotes
        self.onConfirm = onConfirm
        _rating = State(initialValue: initialRating ?? 0)
        _tastingNotes = State(initialValue: initialNotes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Note", systemImage: "star")
                            .foregroundStyle(.secondary)
                        // A stored score can be raised or lowered, never erased.
                        InteractiveStarRating(rating: $rating, allowsUnset: initialRating == nil)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Commentaires", systemImage: "text.quote")
                            .foregroundStyle(.secondary)

                        TextField("Vos impressions, arômes, accords...", text: $tastingNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Note de dégustation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Confirmer", systemImage: "checkmark") {
                        await onConfirm(rating, tastingNotes)
                    }
                    .accessibilityIdentifier("confirm-tasting-button")
                }
            }
            .animation(.default, value: rating)
        }
    }
}

#Preview("Existing note") {
    TastingEditSheet(
        initialRating: 4,
        initialNotes: "Très frais, belle minéralité"
    ) { _, _ in }
}

#Preview("Nothing recorded yet") {
    TastingEditSheet(initialRating: nil, initialNotes: nil) { _, _ in }
}
