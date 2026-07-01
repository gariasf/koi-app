import SwiftUI

/// Car detail. Owned → plan layer invisible, action is Edit. On a plan that allows it →
/// the 4th action becomes Swap car, and a plan card + lineage appear.
struct CarDetailView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var units: Units
    @Environment(\.dismiss) private var dismiss
    private let referenceCar: Car
    @State private var activeSheet: CarSheet?
    @State private var confirmPayoff = false

    init(car: Car) { self.referenceCar = car }

    /// Always read the live car from the store so edits (fuel type, odometer, name…) reflect
    /// immediately, instead of showing the snapshot navigation handed us.
    private var car: Car { garage.car(referenceCar.id) ?? referenceCar }

    private enum CarSheet: Int, Identifiable {
        case log, vault, edit, addReminder, swap, mileageHistory, insights
        var id: Int { rawValue }
    }

    private var plan: Plan? { garage.plan(for: car) }
    private var canSwap: Bool { plan?.allowsSwap == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CarPhotoTile(car: car, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
                header
                actions
                detailsCard
                timeline
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(KoiColors.surface.ignoresSafeArea())
        .navigationTitle(car.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .tint(KoiColors.sage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { activeSheet = .edit }
            }
        }
        .sheet(item: $activeSheet) { which in
            sheetContent(which).presentationDragIndicator(.visible)
        }
        .alert("Mark \(car.displayName) as paid off?", isPresented: $confirmPayoff) {
            Button("Mark as paid off") { garage.markPaidOff(car); Haptics.success() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("From today it's yours. No more monthly cost. What you've paid stays in your history, and you can undo this anytime.")
        }
        .onChange(of: garage.cars) { _, cars in
            // car removed from its Edit screen → leave the now-stale detail
            if !cars.contains(where: { $0.id == car.id }) { dismiss() }
        }
    }

    @ViewBuilder private func sheetContent(_ which: CarSheet) -> some View {
        switch which {
        case .log:         LogSheetView(car: car).environmentObject(garage)
        case .vault:       InsuranceVaultView(car: car).environmentObject(garage)
        case .edit:        EditCarView(car: car).environmentObject(garage)
        case .addReminder: AddReminderView(car: car).environmentObject(garage)
        case .mileageHistory: MileageHistoryView(car: car).environmentObject(garage)
        case .insights:    InsightsView(car: car).environmentObject(garage).environmentObject(units)
        case .swap:
            if let plan {
                NavigationStack {
                    AddSwapCarView(plan: plan, currentCar: car) { activeSheet = nil }
                        .environmentObject(garage)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.displayName).koiStyle(.carName).foregroundStyle(KoiColors.textPrimary)
                    if !car.subtitle.isEmpty {
                        Text(car.subtitle).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                statusPill
            }
            metaRow
        }
    }

    /// Reflects the car's worst active reminder, not a hardcoded "all good".
    private var status: (label: String, fg: Color, bg: Color, dot: Color) {
        let worst = garage.activeReminders
            .filter { $0.carID == car.id }
            .map { garage.urgency($0) }
            .min(by: { $0.rank < $1.rank })
        switch worst {
        case .overdue:  return ("Needs attention", KoiColors.clay, KoiColors.ochreTint, KoiColors.clay)
        case .comingUp: return ("Coming up", KoiColors.ochreText, KoiColors.ochreTint, KoiColors.ochre)
        default:        return ("All good", KoiColors.sageText, KoiColors.sageTint, KoiColors.sage)
        }
    }

    private var statusPill: some View {
        let s = status
        return HStack(spacing: 6) {
            Circle().fill(s.dot).frame(width: 7, height: 7)
            Text(s.label).koiStyle(.meta).foregroundStyle(s.fg)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(s.bg, in: Capsule())
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            if let plate = car.plate, !plate.isEmpty {
                Text(plate).koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(KoiColors.insetFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            if let odo = car.odometerKm {
                Text(KoiFormat.km(odo)).koiStyle(.monoSm).foregroundStyle(KoiColors.textSecondary)
            }
            Text(car.fuel.label).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            Spacer(minLength: 0)
        }
    }

    // Cost lives on the car page, never on the Glance.
    /// The single car card: plan summary (when on a plan) + spent-so-far + a 2×2 grid with calm
    /// sparklines, the plan extras folded in, and a link to the full insights. One card, no second box.
    @ViewBuilder private var detailsCard: some View {
        let spent = garage.totalSpent(on: car)
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "How it's going")
            if let plan, plan.kind != .owned {
                Text(planLine(plan)).koiStyle(.monoSm).foregroundStyle(KoiColors.textSecondary)
            }
            if spent > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(units.money(spent)).koiStyle(.monoLg).foregroundStyle(KoiColors.textPrimary)
                    Text("spent so far").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            }
            Text(ownershipLine).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            statGrid
            planFooter
            seeFullPicture
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }

    private var statGrid: some View {
        let recent = garage.recentEconomy(for: car)
        return VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                statCell("Per month", garage.distancePerMonth(for: car).map { units.distanceText($0) } ?? "—")
                statCell("Fuel use", recent.map { units.economyText($0.l100) } ?? "—",
                         arrow: recent.flatMap { trendArrow($0.trend) },
                         arrowColor: recent?.trend == .improving ? KoiColors.sageText : KoiColors.ochreText)
            }
            HStack(alignment: .top, spacing: 16) {
                statCell("Running cost", runningCostValue)
                statCell("Full tank", garage.tankRange(for: car).map { "≈\(units.distanceText($0))" } ?? "—")
            }
        }
        .padding(.top, 2)
    }

    /// One quiet number per cell — charts + trend wording live in the full insights, not here.
    private func statCell(_ label: String, _ value: String, arrow: String? = nil, arrowColor: Color = .clear) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                if let arrow { Text(arrow).koiStyle(.body).foregroundStyle(arrowColor) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trendArrow(_ t: EconomyTrend) -> String? {
        switch t {
        case .creepingUp: return "↑"
        case .improving:  return "↓"
        case .steady:     return nil
        }
    }

    /// Plan extras folded into the card (deposit, term, swap, finance payoff, mileage history).
    @ViewBuilder private var planFooter: some View {
        if let plan, plan.kind != .owned {
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.vertical, 2)
                if let dep = plan.initialPayment, dep > 0 {
                    Text("\(units.money(dep)) paid up front").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                if let end = plan.endsAt {
                    Text("Ends \(end.formatted(.dateTime.month(.abbreviated).year()))")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                if plan.allowsSwap {
                    Text(swapText(plan)).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                if plan.kind == .finance { financePayoff(plan) }
                if let cap = plan.mileageCapPerMonth, cap > 0 {
                    cardLink("Mileage history") { activeSheet = .mileageHistory }
                }
            }
        }
    }

    private var seeFullPicture: some View { cardLink("See the full picture") { activeSheet = .insights } }

    private func cardLink(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).koiStyle(.meta).foregroundStyle(KoiColors.sageText)
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(KoiColors.sageText)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var runningCostValue: String {
        guard let rc = garage.runningCost(for: car) else { return "—" }
        let m = rc.perMonth.formatted(.currency(code: units.currencyCode).precision(.fractionLength(0)))
        return "≈\(m)/mo"
    }

    private var ownershipLine: String {
        if let plan, plan.kind != .owned {
            if plan.kind == .finance, let paid = plan.paidOffAt {
                return "Owned · paid off \(paid.formatted(.dateTime.month(.abbreviated).year()))"
            }
            let since = plan.startedAt.formatted(.dateTime.month(.abbreviated).year())
            switch plan.kind {
            case .finance: return "Financing since \(since)"   // "On a finance" is ungrammatical
            default:       return "On a \(plan.kind.label.lowercased()) since \(since)"
            }
        }
        if let year = car.ownedSinceYear { return "Owned since \(String(year))" }
        return "Owned"
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionTile("Log", Ph.pencil) { activeSheet = .log }
            actionTile("Remind", Ph.bell) { activeSheet = .addReminder }
            actionTile("Docs", Ph.folder) { activeSheet = .vault }
            if canSwap {
                actionTile("Swap", Ph.swap) { activeSheet = .swap }
            }
        }
    }

    private func actionTile(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                KoiIcon(name: icon, size: 18).foregroundStyle(KoiColors.textPrimary)
                Text(label).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KoiColors.container, in: RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
                    .strokeBorder(KoiColors.ring, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Finance → owned affordance: mark it paid off (with a nudge once the term ends), or undo.
    @ViewBuilder private func financePayoff(_ plan: Plan) -> some View {
        if let paid = plan.paidOffAt {
            VStack(alignment: .leading, spacing: 2) {
                Text("Paid off \(paid.formatted(.dateTime.day().month(.abbreviated).year())) · now yours")
                    .koiStyle(.meta).foregroundStyle(KoiColors.sageText)
                KoiTextButton(title: "Not paid off after all", systemIcon: "arrow.uturn.backward", role: .accent) {
                    garage.undoPaidOff(car); Haptics.tap()
                }
            }
            .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if garage.financeAwaitingPayoff(car) {
                    Text("The loan term has ended. Is it paid off?")
                        .koiStyle(.meta).foregroundStyle(KoiColors.ochreText)
                }
                KoiTextButton(title: "Mark as paid off", systemIcon: "checkmark.seal") { confirmPayoff = true }
            }
            .padding(.top, 4)
        }
    }

    private func planLine(_ plan: Plan) -> String {
        var parts: [String] = []
        if let p = plan.provider, !p.isEmpty { parts.append(p) }
        if let m = plan.monthlyCost { parts.append(KoiFormat.money(m) + "/mo") }
        if let cap = plan.mileageCapPerMonth { parts.append("\(cap) \(plan.capPeriod.unit) cap") }
        return parts.joined(separator: " · ")
    }

    private func swapText(_ plan: Plan) -> String {
        if let m = plan.swapIntervalMonths {
            return "Swap every \(m) months · plan continues across cars"
        }
        return "Swappable · the plan continues across cars"
    }

    // merged timeline: fuel logs + swap-in / origin event, newest first
    private var timeline: some View {
        let items = timelineItems
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Timeline")
            if items.isEmpty {
                EmptyHint(icon: "clock", text: "Nothing logged yet. Fill-ups and services will show up here.")
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    TimelineRow(title: item.title, subtitle: item.subtitle, isLast: idx == items.count - 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct TLItem { let date: Date; let title: String; let subtitle: String }

    private var timelineItems: [TLItem] {
        var items: [TLItem] = []
        let effMap = garage.efficiencies(for: car)
        for log in garage.fuelLogs(for: car) {
            items.append(TLItem(date: log.date, title: timelineTitle(log, efficiency: effMap[log.id]), subtitle: timelineSubtitle(log)))
        }
        for e in garage.entries(for: car) {
            items.append(TLItem(date: e.date, title: entryTitle(e), subtitle: entrySubtitle(e)))
        }
        if let plan {
            let lineage = garage.lineage(for: plan)
            if let idx = lineage.firstIndex(of: car), idx > 0 {
                let prev = lineage[idx - 1]
                items.append(TLItem(date: car.addedAt,
                                    title: "Swapped \(prev.displayName) → \(car.displayName)",
                                    subtitle: "Same plan continued · \(plan.provider ?? "")"))
            } else {
                items.append(TLItem(date: car.addedAt,
                                    title: plan.kind == .owned ? "Bought" : "Joined \(plan.provider ?? "the plan")",
                                    subtitle: KoiFormat.shortDate(car.addedAt)))
            }
            if let paid = plan.paidOffAt {
                items.append(TLItem(date: paid, title: "Paid off · now yours", subtitle: KoiFormat.shortDate(paid)))
            }
        }
        return items.sorted { $0.date > $1.date }
    }

    private func timelineTitle(_ log: FuelLog, efficiency: Double?) -> String {
        let money = KoiFormat.money(log.amount, code: log.currency)
        if let e = efficiency {
            return "Fuel \(money) · \(KoiFormat.efficiency(e))"
        }
        return "Fuel \(money)"
    }

    private func timelineSubtitle(_ log: FuelLog) -> String {
        [KoiFormat.shortDate(log.date), log.station].compactMap { $0 }.joined(separator: " · ")
    }

    private func entryTitle(_ e: LogEntry) -> String {
        let money = e.amount.map { KoiFormat.money($0) }
        switch e.kind {
        case .expense: return "Expense" + (money.map { " " + $0 } ?? "")
        case .service: return "Service" + (money.map { " " + $0 } ?? "")
        case .note:    return e.note.isEmpty ? "Note" : e.note
        }
    }

    private func entrySubtitle(_ e: LogEntry) -> String {
        var parts = [KoiFormat.shortDate(e.date)]
        if e.kind != .note, !e.note.isEmpty { parts.append(e.note) }
        return parts.joined(separator: " · ")
    }
}

/// One keepsake timeline row: dot + connecting line + title/subtitle.
struct TimelineRow: View {
    let title: String
    let subtitle: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(KoiColors.sage).frame(width: 9, height: 9).padding(.top, 3)
                if !isLast {
                    Rectangle().fill(KoiColors.hairline).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                Text(subtitle).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            .padding(.bottom, isLast ? 0 : 18)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack { CarDetailView(car: Garage.preview.residents.last!) }
        .environmentObject(Garage.preview)
        .environmentObject(Units.preview)
}
