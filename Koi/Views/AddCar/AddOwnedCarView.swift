import SwiftUI

/// Add · Owned — minimal owned-car form (shared car fields).
struct AddOwnedCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var form = CarFormData()

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · Owned") { dismiss() }
            ScrollView {
                CarFieldsSection(data: $form)
                    .padding(.horizontal, KoiSpace.gutter)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
            KoiPrimaryButton(title: "Save car", enabled: form.isValid) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func save() {
        var car = Car(make: "", model: "")
        car.accent = .slate          // owned default tint (overridden if a photo is set)
        form.apply(to: &car)
        garage.addOwnedCar(car)
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview { AddOwnedCarView().environmentObject(Garage(persists: false)) }
