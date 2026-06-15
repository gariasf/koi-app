import SwiftUI

/// Add · On a plan — one form for lease/finance/subscription; the preset sets defaults.
struct AddPlanCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var kind: PlanKind = .subscription
    @State private var provider = ""
    @State private var makeModel = ""
    @State private var monthly = ""
    @State private var mileageCap = ""
    @State private var incInsurance = true
    @State private var incMaintenance = true
    @State private var incRoadside = true
    @State private var allowsSwap = true

    private var canSave: Bool {
        !makeModel.trimmingCharacters(in: .whitespaces).isEmpty
            && !provider.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · On a plan") { dismiss() }

            ScrollView {
                VStack(spacing: 16) {
                    planSegmented
                    Text("Same form for all three — the preset sets the defaults below.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    KoiField(label: "Provider", placeholder: "Mocean", text: $provider)
                    KoiField(label: "Make & model", placeholder: "Hyundai Tucson", text: $makeModel)
                    HStack(alignment: .top, spacing: 12) {
                        KoiField(label: "Monthly", placeholder: "€459", text: $monthly, keyboard: .numberPad)
                        KoiField(label: "Mileage cap", placeholder: "1,500 /mo", text: $mileageCap, mono: true, keyboard: .numberPad)
                    }

                    includedCard
                    swapCard
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            KoiPrimaryButton(title: "Save plan", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: kind) { applyPreset() }
    }

    private var planSegmented: some View {
        HStack(spacing: 4) {
            planSeg("Lease", .lease)
            planSeg("Finance", .finance)
            planSeg("Subscription", .subscription)
        }
        .padding(4)
        .background(KoiColors.insetFill, in: Capsule())
    }

    private func planSeg(_ label: String, _ k: PlanKind) -> some View {
        Button { kind = k } label: {
            Text(label).koiStyle(.meta)
                .foregroundStyle(kind == k ? .white : KoiColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background { if kind == k { Capsule().fill(KoiColors.sage) } }
        }
        .buttonStyle(.plain)
    }

    private var includedCard: some View {
        VStack(spacing: 0) {
            KoiToggleRow(title: "Insurance",
                         subtitle: incInsurance ? "No separate policy to add" : nil,
                         isOn: $incInsurance)
                .padding(14)
            hairline
            KoiToggleRow(title: "Maintenance & service", isOn: $incMaintenance).padding(14)
            hairline
            KoiToggleRow(title: "Roadside assistance", isOn: $incRoadside).padding(14)
        }
        .koiCard(padding: 0)
    }

    private var swapCard: some View {
        KoiToggleRow(title: "Lets you swap cars",
                     subtitle: allowsSwap ? "This plan: every 6 months" : "Off for this plan",
                     isOn: $allowsSwap)
            .koiCard()
    }

    private var hairline: some View {
        Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.horizontal, 14)
    }

    private func applyPreset() {
        switch kind {
        case .subscription:
            incInsurance = true; incMaintenance = true; incRoadside = true; allowsSwap = true
        case .lease, .finance:
            incInsurance = false; incMaintenance = false; incRoadside = false; allowsSwap = false
        case .owned:
            break
        }
    }

    private func save() {
        let trimmed = makeModel.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        var car = Car(make: parts.first ?? trimmed, model: parts.count > 1 ? parts[1] : "")
        car.accent = .sage

        var plan = Plan(kind: kind)
        plan.provider = provider.trimmingCharacters(in: .whitespaces)
        plan.monthlyCost = Decimal(string: monthly.filter { $0.isNumber || $0 == "." })
        plan.mileageCapPerMonth = Int(mileageCap.filter(\.isNumber))
        plan.includesInsurance = incInsurance
        plan.includesMaintenance = incMaintenance
        plan.includesRoadside = incRoadside
        plan.allowsSwap = allowsSwap

        garage.addPlanCar(car, plan: plan)
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview { AddPlanCarView().environmentObject(Garage(persists: false)) }
