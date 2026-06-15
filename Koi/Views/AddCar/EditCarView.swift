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
            ModalHeader(title: "Edit car") { dismiss() }
            ScrollView {
                VStack(spacing: 16) {
                    CarFieldsSection(data: $form)
                    fuelRegionRow
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

    @ViewBuilder private var fuelRegionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fuel region").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Menu {
                Button("Use app default") { form.fuelRegionID = nil }
                ForEach(Province.all) { p in Button(p.name) { form.fuelRegionID = p.id } }
            } label: {
                HStack {
                    Text(form.fuelRegionID.map(Province.name(for:)) ?? "App default")
                        .koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
