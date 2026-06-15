import SwiftUI

/// Add an insurance policy to a car. Creates the policy + a renewal reminder.
struct AddPolicyView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    @State private var insurer = ""
    @State private var number = ""
    @State private var coverage = "Comprehensive"
    @State private var premium = ""
    @State private var validTo = Date().addingTimeInterval(365 * 86_400)

    private var canSave: Bool { !insurer.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Add a policy") { dismiss() }

            ScrollView {
                VStack(spacing: 16) {
                    KoiField(label: "Insurer", placeholder: "Mapfre", text: $insurer)
                    KoiField(label: "Policy number", placeholder: "ES-4471 8820", text: $number, mono: true)
                    KoiField(label: "Coverage", placeholder: "Comprehensive", text: $coverage)
                    KoiField(label: "Premium / yr", placeholder: "€412", text: $premium, keyboard: .numberPad)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Renews").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
                        DatePicker("", selection: $validTo, displayedComponents: .date)
                            .labelsHidden().tint(KoiColors.sage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            KoiPrimaryButton(title: "Save policy", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    private func save() {
        let policy = InsurancePolicy(
            carID: car.id,
            insurer: insurer.trimmingCharacters(in: .whitespaces),
            policyNumber: number.trimmingCharacters(in: .whitespaces),
            coverage: coverage.trimmingCharacters(in: .whitespaces).isEmpty ? "Comprehensive" : coverage,
            premium: Decimal(string: premium.filter { $0.isNumber || $0 == "." }),
            premiumLastYear: nil,
            validFrom: Date(),
            validTo: validTo
        )
        garage.addPolicy(policy)
        dismiss()
    }
}

#Preview { AddPolicyView(car: Garage.preview.residents.first!).environmentObject(Garage.preview) }
