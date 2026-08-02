import SwiftUI

/// Lets the user write to us: a problem to report, or an idea for the app. The
/// message goes straight to Sentry, where the errors already land.
///
/// The send is fire-and-forget: the SDK queues the message and retries on its
/// own, so there is nothing to await and the confirmation below is optimistic.
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: FeedbackKind = .bug
    @State private var message = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Message envoyé", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } footer: {
                        Text("Merci, votre message nous aide à améliorer l'application.")
                    }
                } else {
                    Section {
                        Picker("Sujet", selection: $kind) {
                            Text("Problème").tag(FeedbackKind.bug)
                            Text("Suggestion").tag(FeedbackKind.idea)
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text(kindHint)
                    }

                    Section {
                        TextField("Votre message", text: $message, axis: .vertical)
                            .lineLimit(5...)
                    }

                    Section {
                        Button("Envoyer") { send() }
                            .disabled(trimmedMessage.isEmpty)
                    } footer: {
                        Text("La version de l'application et le modèle d'appareil accompagnent le message. Ni votre nom ni votre adresse e-mail ne sont transmis.")
                    }
                }
            }
            .navigationTitle("Nous écrire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(
                        title: sent ? "Terminé" : "Annuler",
                        systemImage: "xmark",
                        role: .cancel
                    ) { dismiss() }
                }
            }
        }
    }

    private var kindHint: LocalizedStringKey {
        switch kind {
        case .bug: "Décrivez ce que vous faisiez et ce qui s'est passé."
        case .idea: "Dites-nous ce qui manque ou ce qui gagnerait à changer."
        }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        sendFeedback(kind: kind, message: trimmedMessage)
        sent = true
    }
}

#Preview {
    FeedbackSheet()
}
