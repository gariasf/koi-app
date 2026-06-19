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

    // Europe-English coverage tiers (regionalised later, e.g. ES "todo riesgo / terceros").
    private let coverageOptions = ["Comprehensive", "Third-party plus", "Third-party"]
    private var canSave: Bool { !insurer.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New policy")

            ScrollView {
                VStack(spacing: 16) {
                    KoiField(label: "Insurer", placeholder: "Mapfre", text: $insurer)
                    KoiField(label: "Policy number", placeholder: "ES-4471 8820", text: $number, mono: true, uppercased: true)
                    coveragePicker
                    KoiField(label: "Premium", placeholder: "€412", text: $premium, mono: true, keyboard: .decimalPad)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Valid until").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
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

    private var coveragePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coverage").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Menu {
                Picker("Coverage", selection: $coverage) {
                    ForEach(coverageOptions, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack {
                    Text(coverage).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
            }
        }
    }

    private func save() {
        let policy = InsurancePolicy(
            carID: car.id,
            insurer: insurer.trimmingCharacters(in: .whitespaces),
            policyNumber: number.trimmingCharacters(in: .whitespaces),
            coverage: coverage.trimmingCharacters(in: .whitespaces).isEmpty ? "Comprehensive" : coverage,
            premium: KoiFormat.decimal(premium),
            premiumLastYear: nil,
            validFrom: Date(),
            validTo: validTo
        )
        garage.addPolicy(policy)
        dismiss()
    }
}

#Preview { AddPolicyView(car: Garage.preview.residents.first!).environmentObject(Garage.preview) }
