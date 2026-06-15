import SwiftUI

/// Quick-add fuel log. Capture a fill-up in 2–3 taps; efficiency derives silently.
struct LogSheetView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    enum Field { case amount, odometer, liters }

    @State private var amount = ""
    @State private var odometer = ""
    @State private var liters = ""
    @State private var focus: Field = .amount

    private var canSave: Bool {
        (Decimal(string: amount) ?? 0) > 0 && (Double(liters) ?? 0) > 0 && (Int(odometer) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Log a fill-up").koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                Text("\(car.displayName) · Today").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            .padding(.top, 18)

            typePicker
                .padding(.top, 16)
                .padding(.horizontal, KoiSpace.gutter)

            Spacer(minLength: 12)

            Text("€" + (amount.isEmpty ? "0" : amount))
                .font(KoiFont.mono(46, .medium))
                .foregroundStyle(amount.isEmpty ? KoiColors.textSubdued : KoiColors.textPrimary)
                .onTapGesture { focus = .amount }

            HStack(spacing: 14) {
                detailChip(.odometer, value: odometer.isEmpty ? "— km" : "\(odometer) km")
                Text("·").koiStyle(.body).foregroundStyle(KoiColors.textSubdued)
                detailChip(.liters, value: liters.isEmpty ? "— L" : "\(liters) L")
            }
            .padding(.top, 8)

            Spacer(minLength: 12)

            keypad.padding(.horizontal, KoiSpace.gutter)

            KoiPrimaryButton(title: "Save fill-up", systemIcon: "checkmark", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
        .background(KoiColors.sheet.ignoresSafeArea())
    }

    // segmented type picker (only Fuel is functional in this slice)
    private var typePicker: some View {
        HStack(spacing: 4) {
            segment("Fuel", active: true)
            segment("Expense", active: false)
            segment("Service", active: false)
            segment("Note", active: false)
        }
        .padding(4)
        .background(KoiColors.insetFill, in: Capsule())
    }

    private func segment(_ label: String, active: Bool) -> some View {
        Text(label).koiStyle(.meta)
            .foregroundStyle(active ? .white : KoiColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background { if active { Capsule().fill(KoiColors.sage) } }
    }

    private func detailChip(_ field: Field, value: String) -> some View {
        Button { focus = field } label: {
            Text(value).koiStyle(.monoMd)
                .foregroundStyle(focus == field ? KoiColors.sageText : KoiColors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { k in
                Button { tap(k) } label: {
                    Text(k)
                        .font(KoiFont.mono(22, .medium))
                        .foregroundStyle(KoiColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(KoiColors.container, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(KoiColors.ring, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tap(_ key: String) {
        Haptics.tap()
        switch focus {
        case .amount:   amount = edit(amount, key, decimal: true)
        case .odometer: odometer = edit(odometer, key, decimal: false)
        case .liters:   liters = edit(liters, key, decimal: true)
        }
    }

    private func edit(_ s: String, _ key: String, decimal: Bool) -> String {
        if key == "⌫" { return String(s.dropLast()) }
        if key == "." {
            guard decimal, !s.contains(".") else { return s }
            return s.isEmpty ? "0." : s + "."
        }
        return s + key
    }

    private func save() {
        let log = FuelLog(carID: car.id,
                          amount: Decimal(string: amount) ?? 0,
                          liters: Double(liters) ?? 0,
                          odometerKm: Int(odometer) ?? 0,
                          station: nil)
        garage.addFuelLog(log)
        Haptics.success()
        dismiss()
    }
}

#Preview {
    LogSheetView(car: Garage.preview.residents.first!).environmentObject(Garage.preview)
}
