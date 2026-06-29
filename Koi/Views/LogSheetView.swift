import SwiftUI

/// Quick-add. Fuel keeps the fast keypad; Expense / Service / Note are short forms.
/// The header makes the target car the subject (accent dot + name) and — when there's more
/// than one resident — lets you switch car right here, so a quick log never lands on the wrong one.
struct LogSheetView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var fuel: FuelPriceStore
    @Environment(\.dismiss) private var dismiss
    @State private var car: Car

    init(car: Car) { _car = State(initialValue: car) }

    enum LogType: String, CaseIterable { case fuel = "Fuel", odometer = "Odometer", expense = "Expense", service = "Service", note = "Note" }
    enum Field { case amount, perLiter, liters, odometer }

    @State private var type: LogType = {
        let a = ProcessInfo.processInfo.arguments   // dev: `-logtype expense`
        if let i = a.firstIndex(of: "-logtype"), i + 1 < a.count,
           let t = LogType(rawValue: a[i + 1].capitalized) { return t }
        return .fuel
    }()
    @State private var amount = ""        // fuel: the total €; expense/service: the amount
    @State private var perLiter = ""      // fuel: €/L
    @State private var odometer = ""
    @State private var liters = ""
    @State private var filledToFull = true   // fuel: tank-to-tank is what makes L/100km honest; default on
    @State private var note = ""
    @State private var date = Date()      // when it happened — defaults to today, can be backdated
    @State private var focus: Field = .amount
    /// Which of the three coupled fuel fields the user has actually typed, oldest→newest.
    /// The one NOT among the last two is the derived (auto-computed) field.
    @State private var entered: [Field] = []

    var body: some View {
        VStack(spacing: 0) {
            logHeader
            typePicker
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 14)

            dateRow
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 10)

            if type == .fuel { fuelBody } else { otherBody }

            KoiPrimaryButton(title: saveTitle, systemIcon: "checkmark", enabled: canSave) { save() }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(KoiColors.sheet.ignoresSafeArea())
        .onAppear {
            // dev: `-fuelseed` prefills Liters + €/L so the derived Total can be screenshotted
            if ProcessInfo.processInfo.arguments.contains("-fuelseed"), type == .fuel {
                amount = "67.45"; perLiter = "1.429"; entered = [.amount, .perLiter]; focus = .odometer
            }
        }
    }

    // MARK: header — the car is the subject; tap to switch when there's more than one
    private var logHeader: some View {
        VStack(spacing: 0) {
            Group {
                if garage.residents.count > 1 {
                    Menu {
                        ForEach(garage.residents) { c in
                            Button { switchCar(c) } label: {
                                Label(c.displayName, systemImage: c.id == car.id ? "checkmark" : "car")
                            }
                        }
                    } label: { carHeaderLabel(switchable: true) }
                } else {
                    carHeaderLabel(switchable: false)
                }
            }
            .padding(.vertical, 6)   // the tappable car control's own touch target
        }
        .frame(maxWidth: .infinity)
        // Top gap is on the container, NOT the button — so it's dead space below the system
        // grab handle and can't steal the tap (which was dismissing the sheet).
        .padding(.top, 26)
        .padding(.bottom, 12)
        .padding(.horizontal, KoiSpace.gutter)
        .overlay(alignment: .bottom) { Rectangle().fill(KoiColors.hairline).frame(height: 1) }
    }

    private func carHeaderLabel(switchable: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(car.accent.text).frame(width: 9, height: 9)
            Text(car.displayName).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
            if switchable {
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KoiColors.textSubdued)
            }
        }
    }

    private func switchCar(_ c: Car) {
        guard c.id != car.id else { return }
        Haptics.tap()
        car = c
    }

    // MARK: date — when it happened (defaults to today; can be backdated for a past fill/expense)
    private var dateRow: some View {
        HStack {
            Text("Date").koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
            Spacer()
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .tint(KoiColors.sage)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(KoiColors.fieldFill, in: RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: KoiRadius.field, style: .continuous).strokeBorder(KoiColors.border, lineWidth: 1))
    }

    // MARK: type picker
    private var typePicker: some View {
        Picker("Type", selection: $type) {
            ForEach(LogType.allCases, id: \.self) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Fuel (keypad)
    // Liters · €/L · Total are one triangle — enter any two and the third computes. The big
    // number is always the Total (what people remember a fill by); €/L and Liters live as chips
    // below, alongside the optional odometer (which drives the derived efficiency). The focused
    // field shows a pill + a blinking caret so you always know where you're typing.
    private var fuelBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            Button { focusField(.amount) } label: {
                HStack(alignment: .center, spacing: 4) {
                    Text("€" + heroTotalString)
                        .font(KoiFont.mono(46, .medium))
                        .foregroundStyle(heroDimmed ? KoiColors.textSubdued : KoiColors.textPrimary)
                    if focus == .amount { Caret(big: true) }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                chip(.perLiter)
                chip(.liters)
                chip(.odometer)
            }
            .padding(.top, 12)

            if derivedField == nil {
                Text("Enter any two and Koi works out the third.")
                    .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                    .padding(.top, 8)
            }

            if hasQuickActions { quickActions.padding(.top, 14) }

            fullTankToggle.padding(.top, 10)

            if overTank {
                Text("More than the tank holds (\(litersLabel(car.tankCapacityL ?? 0)))")
                    .koiStyle(.meta).foregroundStyle(KoiColors.red)
                    .padding(.top, 8)
            }

            Spacer(minLength: 12)
            keypad.padding(.horizontal, KoiSpace.gutter)
        }
    }

    /// One coupled fuel value. Focused → pill + caret. Auto-computed → a sage "=" + tint so the
    /// live calculation is unmistakable. Otherwise plain.
    private func chip(_ field: Field) -> some View {
        let parts = chipParts(field)
        let focused = field == focus
        let isAuto = !focused && field == derivedField && !parts.number.isEmpty
        return Button { focusField(field) } label: {
            HStack(spacing: 3) {
                if isAuto { Text("=").koiStyle(.monoMd).foregroundStyle(KoiColors.sageText) }
                if !parts.number.isEmpty {
                    Text(parts.number).koiStyle(.monoMd).foregroundStyle(chipColor(field))
                }
                if focused { Caret() }
                Text(parts.unit).koiStyle(.monoMd).foregroundStyle(chipColor(field))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if focused {
                    Capsule().fill(KoiColors.insetFill)
                        .overlay(Capsule().strokeBorder(KoiColors.sage.opacity(0.55), lineWidth: 1))
                } else if isAuto {
                    Capsule().fill(KoiColors.sageTint)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Contextual one-tap: fill the tank to its known size. (No "today's pump price" suggestion —
    /// it's the cheapest *nearby* station's price, which isn't necessarily where you filled up.)
    private var hasQuickActions: Bool { (car.tankCapacityL ?? 0) > 0 }

    @ViewBuilder private var quickActions: some View {
        HStack(spacing: 10) {
            if let tank = car.tankCapacityL, tank > 0 {
                quickPill("Fill to full · \(litersLabel(tank))", icon: "drop.fill") { fillToFull(tank) }
            }
        }
    }

    /// Whether the tank was filled to full — the signal the L/100km math needs. Default on; one tap
    /// marks a partial fill so it's summed into the next full-tank reading instead of measured alone.
    private var fullTankToggle: some View {
        Button { filledToFull.toggle(); Haptics.tap() } label: {
            HStack(spacing: 6) {
                Image(systemName: filledToFull ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                Text("Filled to full").koiStyle(.meta)
            }
            .foregroundStyle(filledToFull ? KoiColors.sageText : KoiColors.textSubdued)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(filledToFull ? KoiColors.sageTint : KoiColors.insetFill))
        }
        .buttonStyle(.plain)
    }

    private func quickPill(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).koiStyle(.meta)
            }
            .foregroundStyle(KoiColors.sageText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(KoiColors.container, in: Capsule())
            .overlay(Capsule().strokeBorder(KoiColors.ring, lineWidth: 1))
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
            if type == .odometer {
                KoiField(label: "Odometer (km)", placeholder: "142,300", text: $odometer, mono: true, keyboard: .numberPad, grouped: true)
                Text("Updates the car’s current reading, and the monthly mileage gauge.")
                    .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
            } else {
                if type != .note {
                    KoiField(label: "Amount", placeholder: "€0", text: $amount, mono: true, keyboard: .decimalPad)
                }
                if type == .service {
                    KoiField(label: "Odometer", placeholder: "142,300", text: $odometer, mono: true, keyboard: .numberPad, grouped: true)
                }
                noteField
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.top, 18)
    }

    private var noteField: some View {
        KoiField(label: type == .note ? "Note" : "What for? (optional)",
                 placeholder: type == .note ? "Add a note…" : "e.g. Car wash",
                 text: $note,
                 axis: .vertical,
                 lineLimit: type == .note ? 3...6 : 1...2)
    }

    // MARK: the fuel triangle — Total · €/L · Liters, any two derive the third
    private let triangle: [Field] = [.amount, .perLiter, .liters]

    /// The field to auto-compute: the one not among the last two the user touched (nil until two are set).
    private var derivedField: Field? {
        let typed = entered.filter { triangle.contains($0) }
        guard typed.count >= 2 else { return nil }
        let lastTwo = Array(typed.suffix(2))
        return triangle.first { !lastTwo.contains($0) }
    }

    private func num(_ s: String) -> Double { KoiFormat.double(s) ?? 0 }

    /// All three values with the derived one filled in.
    private var resolved: (total: Double, perLiter: Double, liters: Double) {
        var t = num(amount), p = num(perLiter), l = num(liters)
        switch derivedField {
        case .amount:   t = l * p
        case .perLiter: p = l > 0 ? t / l : 0
        case .liters:   l = p > 0 ? t / p : 0
        default: break
        }
        return (t, p, l)
    }

    private var overTank: Bool {
        guard let tank = car.tankCapacityL, tank > 0 else { return false }
        return resolved.liters > tank * 1.02   // small tolerance for top-offs / rounding
    }

    // MARK: display
    private var heroTotalString: String {
        if focus == .amount, !amount.isEmpty { return amount }     // actively typing the total
        if derivedField == .amount { let t = resolved.total; return t > 0 ? String(format: "%.2f", t) : "0" }
        return amount.isEmpty ? "0" : amount
    }
    private var heroDimmed: Bool { heroTotalString == "0" }

    /// (number, unit) for a chip. Focused shows the raw value (may be empty → just caret + unit);
    /// the auto field shows its computed value; otherwise the typed value or an em-dash.
    private func chipParts(_ field: Field) -> (number: String, unit: String) {
        switch field {
        case .perLiter:
            let u = "€/L"
            // Show the computed value whenever this is the derived field and untyped — even if focused,
            // so the answer is never hidden behind an empty focused chip.
            if field == derivedField, perLiter.isEmpty, resolved.perLiter > 0 { return (pricePerLiterString(resolved.perLiter), u) }
            if field == focus { return (perLiter, u) }
            return (perLiter.isEmpty ? "—" : perLiter, u)
        case .liters:
            let u = "L"
            if field == derivedField, liters.isEmpty, resolved.liters > 0 { return (litersValue(resolved.liters), u) }
            if field == focus { return (liters, u) }
            return (liters.isEmpty ? "—" : liters, u)
        case .odometer:
            let u = "km"
            if field == focus { return (odometer.isEmpty ? "" : grouped(odometer), u) }
            return (odometer.isEmpty ? "—" : grouped(odometer), u)
        default:
            return ("", "")
        }
    }

    private func chipColor(_ field: Field) -> Color {
        if field == focus { return KoiColors.sageText }
        if field == derivedField { return KoiColors.textSecondary }   // auto-computed (paired with "=" + tint)
        let empty: Bool
        switch field {
        case .perLiter: empty = perLiter.isEmpty
        case .liters:   empty = liters.isEmpty
        case .odometer: empty = odometer.isEmpty
        default:        empty = true
        }
        return empty ? KoiColors.textSubdued : KoiColors.textSecondary
    }

    // MARK: logic
    private var saveTitle: String {
        switch type {
        case .fuel:     return "Save fill-up"
        case .odometer: return "Save odometer"
        case .expense:  return "Save expense"
        case .service:  return "Save service"
        case .note:     return "Save note"
        }
    }

    private var canSave: Bool {
        switch type {
        case .fuel:     let r = resolved; return r.total > 0 || r.liters > 0
        case .odometer: return (Int(odometer.filter(\.isNumber)) ?? 0) > 0
        case .expense:  return (KoiFormat.decimal(amount) ?? 0) > 0
        case .service:  return (KoiFormat.decimal(amount) ?? 0) > 0 || !note.trimmingCharacters(in: .whitespaces).isEmpty
        case .note:     return !note.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    /// Focus a field; if it's the auto-computed one, commit its value first so editing continues from it.
    private func focusField(_ field: Field) {
        if triangle.contains(field), field == derivedField {
            let r = resolved
            switch field {
            case .amount:   if r.total > 0 { amount = String(format: "%.2f", r.total); touch(.amount, amount) }
            case .perLiter: if r.perLiter > 0 { perLiter = pricePerLiterString(r.perLiter); touch(.perLiter, perLiter) }
            case .liters:   if r.liters > 0 { liters = litersValue(r.liters); touch(.liters, liters) }
            default: break
            }
        }
        focus = field
    }

    private func fillToFull(_ tank: Double) {
        Haptics.tap()
        filledToFull = true
        liters = litersValue(tank)
        touch(.liters, liters)
        focus = derivedField == .perLiter ? .amount : (perLiter.isEmpty ? .perLiter : .amount)
    }

    /// Record (or clear) a triangle field in the edit order — newest goes last.
    private func touch(_ field: Field, _ value: String) {
        guard triangle.contains(field) else { return }
        entered.removeAll { $0 == field }
        if !value.isEmpty { entered.append(field) }
    }

    private func tap(_ key: String) {
        Haptics.tap()
        switch focus {
        case .amount:   amount = edit(amount, key, decimal: true);   touch(.amount, amount)
        case .perLiter: perLiter = edit(perLiter, key, decimal: true); touch(.perLiter, perLiter)
        case .liters:   liters = edit(liters, key, decimal: true);   touch(.liters, liters)
        case .odometer: odometer = edit(odometer, key, decimal: false)
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
            let r = resolved
            let total = derivedField == .amount
                ? (KoiFormat.decimal(String(format: "%.2f", r.total)) ?? 0)
                : (KoiFormat.decimal(amount) ?? Decimal(r.total))
            garage.addFuelLog(FuelLog(carID: car.id,
                                      date: date,
                                      amount: total,
                                      liters: r.liters,
                                      odometerKm: Int(odometer.filter(\.isNumber)),
                                      station: nil,
                                      filledToFull: filledToFull))
        case .odometer:
            if let km = Int(odometer.filter(\.isNumber)), km > 0 {
                garage.setOdometer(km, for: car.id, asOf: date)
            }
        case .expense, .service, .note:
            let kind: LogKind = type == .expense ? .expense : (type == .service ? .service : .note)
            garage.addLogEntry(LogEntry(carID: car.id, kind: kind, date: date,
                                        amount: KoiFormat.decimal(amount),
                                        note: note.trimmingCharacters(in: .whitespaces),
                                        odometerKm: Int(odometer.filter(\.isNumber))))
        }
        Haptics.success()
        dismiss()
    }

    // MARK: number formatting
    private func pricePerLiterString(_ p: Double) -> String { String(format: "%.3f", p) }
    private func litersValue(_ l: Double) -> String { l == l.rounded() ? String(Int(l)) : String(format: "%.1f", l) }
    private func litersLabel(_ l: Double) -> String { litersValue(l) + " L" }
    private func grouped(_ s: String) -> String {
        guard let n = Int(s.filter(\.isNumber)) else { return s }
        return n.formatted(.number.grouping(.automatic))
    }
}

/// Blinking text caret — the "you're typing here" signal on the focused fuel field.
private struct Caret: View {
    var big = false
    @State private var visible = true
    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(KoiColors.sage)
            .frame(width: big ? 3 : 2, height: big ? 38 : 17)
            .opacity(visible ? 1 : 0)
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: visible)
            .onAppear { visible = false }
    }
}

#Preview {
    LogSheetView(car: Garage.preview.residents.first!)
        .environmentObject(Garage.preview)
        .environmentObject(FuelPriceStore.preview)
}
