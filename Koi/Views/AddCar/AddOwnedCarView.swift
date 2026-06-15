import SwiftUI

/// Add · Owned — the minimal owned-car form. Land on the Glance with this car active.
struct AddOwnedCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss

    @State private var makeModel = ""
    @State private var year = ""
    @State private var odometer = ""
    @State private var nickname = ""

    private var canSave: Bool {
        !makeModel.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "New car · Owned") { dismiss() }

            ScrollView {
                VStack(spacing: 16) {
                    photoSlot
                    KoiField(label: "Make & model", placeholder: "Volkswagen Golf", text: $makeModel)
                    HStack(alignment: .top, spacing: 12) {
                        KoiField(label: "Year", placeholder: "2018", text: $year, keyboard: .numberPad)
                        KoiField(label: "Odometer", placeholder: "142,300 km", text: $odometer, mono: true, keyboard: .numberPad)
                    }
                    KoiField(label: "Nickname (optional)", placeholder: "Betsy", text: $nickname,
                             hint: "Shown instead of the model")
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            KoiPrimaryButton(title: "Save car", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    // TODO: native PhotosPicker (P9); prototype used a drag-drop placeholder.
    private var photoSlot: some View {
        RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous)
            .fill(KoiColors.insetFill)
            .frame(height: 150)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(KoiColors.textSubdued)
                    Text("Add a photo (optional)")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous)
                    .strokeBorder(KoiColors.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
    }

    private func save() {
        // Naive split: first word = make, remainder = model. Good enough for the slice.
        let trimmed = makeModel.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        var car = Car(make: parts.first ?? trimmed,
                      model: parts.count > 1 ? parts[1] : "")
        car.year = Int(year.filter(\.isNumber))
        car.odometerKm = Int(odometer.filter(\.isNumber))
        let nick = nickname.trimmingCharacters(in: .whitespaces)
        car.nickname = nick.isEmpty ? nil : nick
        car.accent = .slate
        garage.addOwnedCar(car)
        dismiss()
    }
}

#Preview { AddOwnedCarView().environmentObject(Garage(persists: false)) }
