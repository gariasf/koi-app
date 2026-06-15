import SwiftUI

/// Edit an existing car — works for any car. Car fields always; plan fields too when the
/// car sits on a lease/finance/subscription plan. Add or replace the photo anytime.
struct EditCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    @State private var form: CarFormData
    @State private var plan = PlanFormData()
    @State private var editsPlan = false

    init(car: Car) {
        self.car = car
        _form = State(initialValue: CarFormData(from: car))
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Edit car")
            ScrollView {
                VStack(spacing: 16) {
                    CarFieldsSection(data: $form)
                    if editsPlan {
                        Eyebrow(text: "Plan")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        PlanKindSegmented(kind: $plan.kind)
                        PlanFieldsSection(data: $plan)
                    }
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            KoiPrimaryButton(title: "Save changes", enabled: form.isValid) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let p = garage.plan(for: car), p.kind != .owned {
                plan = PlanFormData(from: p)
                editsPlan = true
            }
        }
    }

    private func save() {
        var updated = car
        form.apply(to: &updated)
        garage.updateCar(updated)
        if editsPlan, var p = garage.plan(for: car) {
            plan.apply(to: &p)
            garage.updatePlan(p)
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    let g = Garage.preview
    return EditCarView(car: g.residents.first!).environmentObject(g)
}
