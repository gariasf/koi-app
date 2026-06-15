import SwiftUI
import PhotosUI
import UIKit

/// Editable car fields, shared by every flow that creates or edits a resident car
/// (owned / on-a-plan / edit). Keeps the forms spatially + behaviourally identical.
struct CarFormData {
    var photoData: Data?
    var makeModel = ""
    var year = ""
    var odometer = ""
    var plate = ""
    var nickname = ""
    var fuelRegionID: String?

    init() {}

    init(from car: Car) {
        photoData = car.photo
        makeModel = [car.make, car.model].filter { !$0.isEmpty }.joined(separator: " ")
        year = car.year.map(String.init) ?? ""
        odometer = car.odometerKm.map(String.init) ?? ""
        plate = car.plate ?? ""
        nickname = car.nickname ?? ""
        fuelRegionID = car.fuelRegionID
    }

    var isValid: Bool { !makeModel.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Write the fields onto a car (new or existing), deriving the accent from a new photo.
    func apply(to car: inout Car) {
        let trimmed = makeModel.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        car.make = parts.first ?? trimmed
        car.model = parts.count > 1 ? parts[1] : ""
        car.year = Int(year.filter(\.isNumber))
        car.odometerKm = Int(odometer.filter(\.isNumber))
        let p = plate.trimmingCharacters(in: .whitespaces)
        car.plate = p.isEmpty ? nil : p
        let n = nickname.trimmingCharacters(in: .whitespaces)
        car.nickname = n.isEmpty ? nil : n
        car.fuelRegionID = fuelRegionID
        car.photo = photoData
        if let photoData, let image = UIImage(data: photoData) {
            car.accent = CarAccent.derive(from: image)
        }
    }
}

struct CarFieldsSection: View {
    @Binding var data: CarFormData
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            photoSlot
            KoiField(label: "Make & model", placeholder: "Volkswagen Golf", text: $data.makeModel)
            HStack(alignment: .top, spacing: 12) {
                KoiField(label: "Year", placeholder: "2018", text: $data.year, keyboard: .numberPad)
                KoiField(label: "Odometer", placeholder: "142,300 km", text: $data.odometer, mono: true, keyboard: .numberPad)
            }
            KoiField(label: "Plate (optional)", placeholder: "4821 KPD", text: $data.plate, mono: true)
            KoiField(label: "Nickname (optional)", placeholder: "Betsy", text: $data.nickname,
                     hint: "Shown instead of the model")
        }
    }

    private var photoSlot: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                if let d = data.photoData, let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    KoiColors.insetFill
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(KoiColors.textSubdued)
                        Text(data.photoData == nil ? "Add a photo (optional)" : "Change photo")
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
                                  style: StrokeStyle(lineWidth: 1, dash: data.photoData == nil ? [5, 4] : []))
            )
        }
        .buttonStyle(.plain)
        .onChange(of: photoItem) {
            Task {
                if let d = try? await photoItem?.loadTransferable(type: Data.self) { data.photoData = d }
            }
        }
    }
}
