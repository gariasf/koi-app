import SwiftUI

/// Add · On a plan — one form for lease/finance/subscription. Now carries full car
/// fields (year/odometer/plate/photo), plan term dates, and an editable swap interval.
struct AddPlanCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var car = CarFormData()
    @State private var plan = PlanFormData()

    private var canSave: Bool { car.isValid && plan.isValid }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · On a plan") { dismiss() }
            ScrollView {
                VStack(spacing: 16) {
                    PlanKindSegmented(kind: $plan.kind)
                    Text("Same form for all three — the preset sets the defaults below.")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CarFieldsSection(data: $car)
                    PlanFieldsSection(data: $plan)
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
