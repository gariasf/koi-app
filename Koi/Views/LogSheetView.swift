import SwiftUI

/// Quick-add. Fuel keeps the fast keypad; Expense / Service / Note are short forms.
struct LogSheetView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car

    enum LogType: String, CaseIterable { case fuel = "Fuel", expense = "Expense", service = "Service", note = "Note" }
    enum Field { case amount, odometer, liters }

    @State private var type: LogType = {
        let a = ProcessInfo.processInfo.arguments   // dev: `-logtype expense`
        if let i = a.firstIndex(of: "-logtype"), i + 1 < a.count,
           let t = LogType(rawValue: a[i + 1].capitalized) { return t }
        return .fuel
    }()
    @State private var amount = ""
    @State private var odometer = ""
    @State private var liters = ""
    @State private var note = ""
    @State private var focus: Field = .amount

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Log · \(car.displayName)") { dismiss() }
            typePicker
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 14)

            if type == .fuel { fuelBody } else { otherBody }

            KoiPrimaryButton(title: saveTitle, systemIcon: "checkmark", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(KoiColors.sheet.ignoresSafeArea())
    }

    // MARK: type picker
    private var typePicker: some View {
        HStack(spacing: 4) {
            ForEach(LogType.allCases, id: \.self) { t in
                Button { type = t } label: {
                    Text(t.rawValue).koiStyle(.meta)
                        .foregroundStyle(type == t ? .white : KoiColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background { if type == t { Capsule().fill(KoiColors.sage) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(KoiColors.insetFill, in: Capsule())
    }

    // MARK: Fuel (keypad)
    private var fuelBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            Text("€" + (amount.isEmpty ? "0" : amount))
                .font(KoiFont.mono(46, .medium))
                .foregroundStyle(amount.isEmpty ? KoiColors.textSubdued : KoiColors.textPrimary)
                .onTapGesture { focus = .amount }
            HStack(spacing: 14) {
                detailChip(.odometer, value: odometer.isEmpty ? "— km" : "\(odometer) km")
                Text("·").koiStyle(.body).foregroundStyle(KoiColors.textSubdued)
                detailChip(.liters, value: liters.isEmpty ? "— L" : "\(liters) L")
            }
            .padding(.top, 10)
            Spacer(minLength: 16)
            keypad.padding(.horizontal, KoiSpace.gutter)
        }
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
                        .frame(height: 48)
                        .background(KoiColors.container, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(KoiColors.ring, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Expense / Service / Note (forms)
    private var otherBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if type != .note {
                KoiField(label: "Amount", placeholder: "€0", text: $amount, mono: true, keyboard: .decimalPad)
            }
            if type == .service {
                KoiField(label: "Odometer", placeholder: "142,300 km", text: $odometer, mono: true, keyboard: .numberPad)
            }
            noteField
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.top, 18)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(type == .note ? "Note" : "What for? (optional)")
                .koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            TextField(type == .note ? "Add a note…" : "e.g. Car wash", text: $note, axis: .vertical)
                .koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
                .lineLimit(type == .note ? 3...6 : 1...2)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
        }
    }

    // MARK: logic
    private var saveTitle: String {
        switch type {
        case .fuel:    return "Save fill-up"
        case .expense: return "Save expense"
        case .service: return "Save service"
        case .note:    return "Save note"
        }
    }

    private var canSave: Bool {
        switch type {
        case .fuel:    return (Decimal(string: amount) ?? 0) > 0 && (Double(liters) ?? 0) > 0 && (Int(odometer) ?? 0) > 0
        case .expense: return (Decimal(string: amount) ?? 0) > 0
        case .service: return (Decimal(string: amount) ?? 0) > 0 || !note.trimmingCharacters(in: .whitespaces).isEmpty
        case .note:    return !note.trimmingCharacters(in: .whitespaces).isEmpty
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
        switch type {
        case .fuel:
            garage.addFuelLog(FuelLog(carID: car.id,
                                      amount: Decimal(string: amount) ?? 0,
                                      liters: Double(liters) ?? 0,
                                      odometerKm: Int(odometer) ?? 0,
                                      station: nil))
        case .expense, .service, .note:
            let kind: LogKind = type == .expense ? .expense : (type == .service ? .service : .note)
            garage.addLogEntry(LogEntry(carID: car.id, kind: kind,
                                        amount: Decimal(string: amount.filter { $0.isNumber || $0 == "." }),
                                        note: note.trimmingCharacters(in: .whitespaces),
                                        odometerKm: Int(odometer.filter(\.isNumber))))
        }
        Haptics.success()
        dismiss()
    }
}

#Preview {
    LogSheetView(car: Garage.preview.residents.first!).environmentObject(Garage.preview)
}
