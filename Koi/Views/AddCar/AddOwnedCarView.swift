import SwiftUI
import PhotosUI
import UIKit

/// Add · Owned — the minimal owned-car form. Land on the Glance with this car active.
struct AddOwnedCarView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    var onSaved: (() -> Void)? = nil

    @State private var makeModel = ""
    @State private var year = ""
    @State private var odometer = ""
    @State private var nickname = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

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
        .toolbar(.hidden, for: .navigationBar)
    }

    private var photoSlot: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                if let photoData, let ui = UIImage(data: photoData) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    KoiColors.insetFill
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(KoiColors.textSubdued)
                        Text("Add a photo (optional)")
                            .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KoiRadius.cardSmall, style: .continuous)
                    .strokeBorder(KoiColors.border,
                                  style: StrokeStyle(lineWidth: 1, dash: photoData == nil ? [5, 4] : []))
            )
        }
        .buttonStyle(.plain)
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
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
        car.photo = photoData
        if let photoData, let image = UIImage(data: photoData) {
            car.accent = CarAccent.derive(from: image)   // auto per-car accent from the photo
        } else {
            car.accent = .slate
        }
        garage.addOwnedCar(car)
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

#Preview { AddOwnedCarView().environmentObject(Garage(persists: false)) }
