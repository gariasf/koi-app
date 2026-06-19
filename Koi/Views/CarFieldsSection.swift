import SwiftUI
import PhotosUI
import UIKit

/// Editable car fields, shared by every flow that creates or edits a resident car
/// (owned / on-a-plan / edit). Basics stay visible; specs hide under "More details".
struct CarFormData {
    var photoData: Data?
    var makeModel = ""
    var year = ""
    var odometer = ""
    var plate = ""
    var nickname = ""
    var fuelType: FuelType = .petrol
    // advanced / optional
    var tank = ""
    var initialOdometer = ""
    var registrationYear = ""
    var purchaseYear = ""
    var power = ""
    var fiscalPower = ""
    var purchasePrice = ""
    var vin = ""

    init() {}

    init(from car: Car) {
        photoData = car.photo
        makeModel = [car.make, car.model].filter { !$0.isEmpty }.joined(separator: " ")
        year = car.year.map(String.init) ?? ""
        odometer = car.odometerKm.map(String.init) ?? ""
        plate = car.plate ?? ""
        nickname = car.nickname ?? ""
        fuelType = car.fuel
        tank = car.tankCapacityL.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
        initialOdometer = car.initialOdometerKm.map(String.init) ?? ""
        registrationYear = car.registrationYear.map(String.init) ?? ""
        purchaseYear = car.purchaseYear.map(String.init) ?? ""
        power = car.powerHP.map(String.init) ?? ""
        fiscalPower = car.fiscalPowerCV.map { String($0) } ?? ""
        purchasePrice = car.purchasePrice.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
        vin = car.vin ?? ""
    }

    var isValid: Bool { !makeModel.trimmingCharacters(in: .whitespaces).isEmpty }

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
        car.fuelType = fuelType
        car.tankCapacityL = KoiFormat.double(tank)
        car.initialOdometerKm = Int(initialOdometer.filter(\.isNumber))
        car.registrationYear = Int(registrationYear.filter(\.isNumber))
        car.purchaseYear = Int(purchaseYear.filter(\.isNumber))
        car.powerHP = Int(power.filter(\.isNumber))
        car.fiscalPowerCV = KoiFormat.double(fiscalPower)
        car.purchasePrice = KoiFormat.decimal(purchasePrice)
        let vinTrimmed = vin.trimmingCharacters(in: .whitespaces)
        car.vin = vinTrimmed.isEmpty ? nil : vinTrimmed
        car.photo = photoData
        if let photoData, let image = UIImage(data: photoData) {
            car.accent = CarAccent.derive(from: image)
        }
    }
}

struct CarFieldsSection: View {
    @Binding var data: CarFormData
    /// Owned cars show ownership fields (bought year + purchase price); cars on a plan don't —
    /// a plan has a deposit, not a purchase price.
    var ownership: Bool = true
    @State private var photoItem: PhotosPickerItem?
    @State private var showMore = false

    var body: some View {
        VStack(spacing: 16) {
            photoSlot
            KoiField(label: "Make & model", placeholder: "Volkswagen Golf", text: $data.makeModel)
            HStack(alignment: .top, spacing: 12) {
                KoiField(label: "Registered", placeholder: "2018", text: $data.registrationYear, keyboard: .numberPad)
                KoiField(label: "Odometer (now)", placeholder: "142,300", text: $data.odometer, mono: true, keyboard: .numberPad, grouped: true)
            }
            KoiField(label: "Odometer at start (optional)", placeholder: "120,000", text: $data.initialOdometer,
                     mono: true, keyboard: .numberPad,
                     hint: "The reading when you first got the car, for total km driven.", grouped: true)
            KoiField(label: "Plate (optional)", placeholder: "4821 KPD", text: $data.plate, mono: true, uppercased: true)
            KoiField(label: "Nickname (optional)", placeholder: "Betsy", text: $data.nickname,
                     hint: "Shown instead of the model")
            fuelTypePicker
            moreDetails
        }
    }

    private var fuelTypePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fuel type").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Menu {
                Picker("Fuel type", selection: $data.fuelType) {
                    ForEach(FuelType.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                HStack {
                    Text(data.fuelType.label).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundStyle(KoiColors.textSubdued)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
            }
        }
    }

    @ViewBuilder private var moreDetails: some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { showMore.toggle() } } label: {
            HStack(spacing: 6) {
                Text(showMore ? "Fewer details" : "More details").koiStyle(.body)
                Image(systemName: showMore ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(KoiColors.sageText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)

        if showMore {
            KoiField(label: "Model year", placeholder: "2018", text: $data.year, keyboard: .numberPad,
                     hint: "Only if it differs from the registration year")
            KoiField(label: "VIN (optional)", placeholder: "WVWZZZ1KZAW000000", text: $data.vin, mono: true, uppercased: true)
            HStack(alignment: .top, spacing: 12) {
                KoiField(label: "Power (CV)", placeholder: "150", text: $data.power, mono: true, keyboard: .numberPad)
                KoiField(label: "Fiscal power", placeholder: "11,88", text: $data.fiscalPower, mono: true, keyboard: .decimalPad)
            }
            if data.fuelType != .electric {
                KoiField(label: "Tank size (L)", placeholder: "50", text: $data.tank, mono: true, keyboard: .decimalPad,
                         hint: "Lets you tap “Fill to full” when you log fuel")
            }
            if ownership {
                HStack(alignment: .top, spacing: 12) {
                    KoiField(label: "Bought", placeholder: "2021", text: $data.purchaseYear, keyboard: .numberPad)
                    KoiField(label: "Purchase price (€)", placeholder: "18,500", text: $data.purchasePrice, mono: true,
                             keyboard: .decimalPad)
                }
            }
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
                guard let raw = try? await photoItem?.loadTransferable(type: Data.self) else { return }
                // downscale + strip metadata off the main actor, then assign on it
                let prepared = await Task.detached { UIImage(data: raw)?.preparedForStorage() ?? raw }.value
                await MainActor.run { data.photoData = prepared }
            }
        }
    }
}
