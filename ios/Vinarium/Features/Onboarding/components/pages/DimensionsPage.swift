import SwiftUI

struct DimensionsPage: View {
    @Binding var rows: Int
    @Binding var cols: Int
    @Binding var zones: Int
    var nextTitle: LocalizedStringKey = "Continuer"
    var isBusy = false
    var onNext: () -> Void
    var onBack: () -> Void

    private var capacity: Int { rows * cols }
    private var lastRowLabel: String {
        String(UnicodeScalar(65 + max(0, rows - 1))!)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    Stepper(value: $rows, in: 1...OnboardingLimits.maxRows) {
                        LabeledContent("Rangées", value: "\(rows) (A → \(lastRowLabel))")
                    }
                    .accessibilityIdentifier("onboarding-rows-stepper")
                    Stepper(value: $cols, in: 1...OnboardingLimits.maxCols) {
                        LabeledContent("Emplacements par rangée", value: "\(cols)")
                    }
                    .accessibilityIdentifier("onboarding-cols-stepper")
                } header: {
                    Text("Dimensions de la cave")
                } footer: {
                    Text("Les rangées sont étiquetées de A à Z (26 au maximum).")
                }

                Section {
                    Picker("Zones de température", selection: $zones) {
                        ForEach(1...OnboardingLimits.maxZones, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("onboarding-zones-picker")
                } header: {
                    Text("Zones de température")
                } footer: {
                    Text("Nombre de compartiments à températures indépendantes de votre cave.")
                }

                Section {
                    LabeledContent("Capacité totale") {
                        Text("\(capacity) emplacements").fontWeight(.semibold)
                    }
                }
            }

            Button(action: onNext) {
                Group {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text(nextTitle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)
            .padding()
            .accessibilityIdentifier("onboarding-dimensions-next")
        }
        .navigationTitle("Dimensions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIconButton(title: "Retour", systemImage: "chevron.left", action: onBack)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DimensionsPage(rows: .constant(12), cols: .constant(6), zones: .constant(2), onNext: {}, onBack: {})
    }
}
