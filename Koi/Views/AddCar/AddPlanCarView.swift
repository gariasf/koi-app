import SwiftUI

/// Add · On a plan — one form for lease/finance/subscription. Now carries full car
/// fields (year/odometer/plate/photo), plan term dates, and an editable swap interval.
struct AddPlanCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var car = CarFormData()
    @State private var plan: PlanFormData = {
        var p = PlanFormData()
        let a = ProcessInfo.processInfo.arguments   // dev: `-plankind finance`
        if let i = a.firstIndex(of: "-plankind"), i + 1 < a.count, let k = PlanKind(rawValue: a[i + 1]) {
            p.kind = k; p.applyPreset()
        }
        return p
    }()

    private var canSave: Bool { car.isValid && plan.isValid }

    /// A short, plain description of the selected plan — shown under the type picker.
    private var kindBlurb: String {
        switch plan.kind {
        case .subscription, .lease: return "A car you pay for monthly and hand back at the end. Some plans include insurance or upkeep, and some let you swap cars."
        case .finance:              return "You're buying the car in monthly payments. It's yours once it's paid off."
        case .owned:                return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · On a plan")
            ScrollView {
                VStack(spacing: 16) {
                    PlanKindSegmented(kind: $plan.kind)
                    Text(kindBlurb)
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    CarFieldsSection(data: $car, ownership: false)
                    PlanFieldsSection(data: $plan)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            KoiPrimaryButton(title: "Save car", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: plan.kind) { plan.applyPreset() }
    }

    private func save() {
        var newCar = Car(make: "", model: "")
        newCar.accent = .sage
        car.apply(to: &newCar)
        var newPlan = Plan(kind: plan.kind)
        plan.apply(to: &newPlan)
        garage.addPlanCar(newCar, plan: newPlan)
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview { AddPlanCarView().environmentObject(Garage(persists: false)) }
