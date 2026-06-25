import SwiftUI

/// A reminder, opened. Two shapes:
/// • a real reminder (inspection / service / insurance) → context + a one-tap resolve or a
///   low-guilt snooze;
/// • the live mileage-cap gauge → it can't be "done" or "snoozed" (it's a monthly meter), so it
///   shows the gauge and lets you correct the odometer in place — the one input that moves it.
struct ReminderDetailView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let reminder: Reminder

    @State private var odoText = ""
    @State private var didUpdate = false

    private var urgency: Urgency { garage.urgency(reminder) }
    private var isGauge: Bool { reminder.kind == .mileageCap }
    private var car: Car? { garage.car(reminder.carID) }
    private var gaugeTitle: String { "Mileage this " + (car.flatMap { garage.plan(for: $0)?.capPeriod.noun } ?? "month") }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: isGauge ? gaugeTitle : "Reminder")
            ScrollView { isGauge ? AnyView(gaugeContent) : AnyView(reminderContent) }
            footer
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .onAppear { if odoText.isEmpty, let km = car?.odometerKm { odoText = String(km) } }
        .onChange(of: odoText) { _, _ in didUpdate = false }
    }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
            .fill(urgency.tile.bg)
            .frame(width: 64, height: 64)
            .overlay(Image(systemName: reminder.kind.icon).font(.system(size: 26, weight: .regular))
                .foregroundStyle(urgency.tile.fg))
            .padding(.top, 12)
    }

    // MARK: live mileage-cap gauge
    private var pool: Garage.MileagePool? { car.flatMap { garage.mileagePool(for: $0) } }
    private var noun: String { car.flatMap { garage.plan(for: $0)?.capPeriod.noun } ?? "month" }
    private var used: Int { car.flatMap { garage.kmThisCycle(for: $0) } ?? reminder.monthlyUsedKm ?? 0 }
    // When the plan pools unused km, the real budget this cycle is cap + carry-over.
    private var cap: Int { pool?.available ?? reminder.monthlyCapKm ?? 0 }
    private var breakdown: String? {
        guard let p = pool else { return nil }
        let base = "\(p.cap.formatted()) this \(noun)"
        if p.carryOver > 0 { return "\(base) · +\(p.carryOver.formatted()) carried over" }
        if p.carryOver < 0 { return "\(base) · −\((-p.carryOver).formatted()) overdrawn" }
        return base
    }
    private var fraction: Double { cap > 0 ? min(1, Double(used) / Double(cap)) : 0 }
    private var gaugeColor: Color {
        if used > cap { return KoiColors.clay }   // over the cap = a calm clay, not the alarm red
        return fraction >= 0.8 ? KoiColors.ochre : KoiColors.sage
    }

    private var gaugeContent: some View {
        VStack(spacing: 18) {
            iconTile
            Text(car?.displayName ?? "Your car")
                .koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("\(used.formatted()) / \(cap.formatted()) km")
                    .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                if let breakdown {
                    Text(breakdown)
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                        .multilineTextAlignment(.center)
                }
            }
            gaugeBar
            Text(gaugeFootnote)
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .multilineTextAlignment(.center)

            odometerCard
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.bottom, 12)
    }

    private var gaugeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(KoiColors.insetFill)
                Capsule().fill(gaugeColor).frame(width: max(10, geo.size.width * fraction))
            }
        }
        .frame(height: 10)
    }

    private var gaugeFootnote: String {
        let days = car.map { garage.daysUntilMileageReset(for: $0) } ?? 0
        let resets = days == 0 ? "resets today" : "resets in \(days) day\(days == 1 ? "" : "s")"
        if used > cap { return "\((used - cap).formatted()) km over · \(resets)" }
        return "\(max(0, cap - used).formatted()) km to go · \(resets)"
    }

    private var odometerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            KoiField(label: "Odometer (km)", placeholder: "Current reading",
                     text: $odoText, mono: true, keyboard: .numberPad, grouped: true)
            Text("Koi reads the month from your odometer. Update it and the gauge follows.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
        }
        .koiCard()
        .padding(.top, 4)
    }

    // MARK: standard reminder
    private var reminderContent: some View {
        VStack(spacing: 18) {
            iconTile
            VStack(spacing: 6) {
                Text(reminder.title).koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                Text(reminder.detail).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
            }
            .multilineTextAlignment(.center)

            Text(garage.countdown(reminder))
                .koiStyle(.monoMd).foregroundStyle(urgency.countdownColor)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(urgency.tile.bg, in: Capsule())

            if let date = reminder.dueDate {
                infoCard(label: "Due", value: date.formatted(.dateTime.day().month(.wide).year()))
            }
            if reminder.kind == .insurance, let policy = policyForReminder { policyMiniCard(policy) }

            Text("No rush. Koi will nudge you again closer to the time.")
                .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.bottom, 12)
    }

    // MARK: footer (actions differ by shape)
    @ViewBuilder private var footer: some View {
        if isGauge {
            KoiPrimaryButton(title: didUpdate ? "Updated" : "Update odometer",
                             systemIcon: didUpdate ? "checkmark" : nil, enabled: canUpdate) {
                if let km = parsedOdo {
                    garage.setOdometer(km, for: reminder.carID); Haptics.success(); didUpdate = true
                }
            }
            .padding(.horizontal, KoiSpace.gutter).padding(.top, 8).padding(.bottom, 12)
        } else {
            VStack(spacing: 10) {
                KoiPrimaryButton(title: primaryTitle, systemIcon: "checkmark") {
                    garage.resolve(reminder); Haptics.success(); dismiss()
                }
                KoiTextButton(title: "Remind me later", role: .muted) {
                    garage.snooze(reminder); Haptics.tap(); dismiss()
                }
            }
            .padding(.horizontal, KoiSpace.gutter).padding(.top, 8).padding(.bottom, 12)
        }
    }

    private var parsedOdo: Int? { Int(odoText.filter(\.isNumber)) }
    private var canUpdate: Bool {
        guard let km = parsedOdo, km > 0 else { return false }
        return km != (car?.odometerKm ?? -1)
    }
    private var primaryTitle: String {
        switch reminder.kind {
        case .insurance:  return "Mark as renewed"
        case .inspection: return "Mark as passed"
        default:          return "Mark as done"
        }
    }

    private func infoCard(label: String, value: String) -> some View {
        HStack {
            Text(label).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
            Spacer()
            Text(value).koiStyle(.body).foregroundStyle(KoiColors.textPrimary)
        }
        .koiCard()
    }

    private var policyForReminder: InsurancePolicy? {
        garage.policies.first { $0.carID == reminder.carID }
    }

    private func policyMiniCard(_ p: InsurancePolicy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(KoiColors.sage)
                Text(p.insurer).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Spacer()
                Text(p.policyNumber).koiStyle(.monoSm).foregroundStyle(KoiColors.textSecondary)
            }
            HStack(spacing: 10) {
                if let prem = p.premium {
                    Text(KoiFormat.money(prem, code: p.currency) + "/yr")
                        .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                }
                if let last = p.premiumLastYear {
                    Text("last year " + KoiFormat.money(last, code: p.currency))
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                Spacer(minLength: 0)
            }
        }
        .koiCard()
    }
}

private extension Urgency {
    var tile: GlanceTint {
        switch self {
        case .neutral:  return .neutral
        case .comingUp: return .ochre
        case .overdue:  return .red
        }
    }
    var countdownColor: Color {
        switch self {
        case .neutral:  return KoiColors.textSubdued
        case .comingUp: return KoiColors.ochreText
        case .overdue:  return KoiColors.red
        }
    }
}

#Preview {
    let g = Garage.preview
    return ReminderDetailView(reminder: g.activeReminders.first { $0.kind == .mileageCap } ?? g.comingUp.first!)
        .environmentObject(g)
}
