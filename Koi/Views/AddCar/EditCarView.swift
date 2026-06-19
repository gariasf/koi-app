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
    @State private var confirmDelete = false

    init(car: Car) {
        self.car = car
        _form = State(initialValue: CarFormData(from: car))
    }

    private var isOwnedCar: Bool { (garage.plan(for: car)?.kind ?? .owned) == .owned }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Edit car")
            ScrollView {
                VStack(spacing: 16) {
                    CarFieldsSection(data: $form, ownership: isOwnedCar)
                    if editsPlan {
                        Eyebrow(text: "Plan · \(plan.kind.label)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        PlanFieldsSection(data: $plan)
                    }
                    archiveButton
                    removeButton
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

    @ViewBuilder private var archiveButton: some View {
        if car.isArchived {
            Button {
                garage.unarchiveCar(car); Haptics.success(); dismiss()
            } label: {
                Label("Move back to garage", systemImage: "tray.and.arrow.up")
                    .koiStyle(.body).foregroundStyle(car.accent.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        } else {
            Button {
                garage.archiveCar(car); Haptics.success(); dismiss()
            } label: {
                Label("Archive car", systemImage: "archivebox")
                    .koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var removeButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Text("Remove from garage")
                .koiStyle(.body).foregroundStyle(KoiColors.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .confirmationDialog("Remove \(car.displayName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove from garage", role: .destructive) {
                garage.deleteCar(car); Haptics.success(); dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deletes this car and its logs, reminders and documents. This can’t be undone.")
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
