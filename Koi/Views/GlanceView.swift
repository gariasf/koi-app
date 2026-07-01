import SwiftUI

// MARK: - Shared Glance building blocks (used across several screens)

enum GlanceTint {
    case neutral, sage, ochre, red

    var bg: Color {
        switch self {
        case .neutral: return KoiColors.insetFill
        case .sage:    return KoiColors.sageTint
        case .ochre:   return KoiColors.ochreTint
        case .red:     return KoiColors.red.opacity(0.12)
        }
    }
    var fg: Color {
        switch self {
        case .neutral: return KoiColors.textSecondary
        case .sage:    return KoiColors.sage
        case .ochre:   return KoiColors.ochre
        case .red:     return KoiColors.red
        }
    }
}

/// NOTE: SF Symbols are scaffold placeholders. The handoff specifies Lucide icons.
struct IconTile: View {
    let systemName: String
    var tint: GlanceTint = .neutral
    var body: some View {
        RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
            .fill(tint.bg)
            .frame(width: 42, height: 42)
            .overlay(KoiIcon(name: systemName, size: 18).foregroundStyle(tint.fg))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued) }
}

/// One compact card: eyebrow + icon tile + (title/subtitle) + optional trailing mono.
struct GlanceCard: View {
    let eyebrow: String
    let icon: String
    var tint: GlanceTint = .neutral
    let title: String
    var titleMono: Bool = false
    let subtitle: String
    var trailing: String? = nil
    var trailingMeta: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: eyebrow)
            HStack(spacing: 12) {
                IconTile(systemName: icon, tint: tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).koiStyle(titleMono ? .monoMd : .listTitle).foregroundStyle(KoiColors.textPrimary)
                    Text(subtitle).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                Spacer(minLength: 8)
                if trailing != nil || trailingMeta != nil {
                    VStack(alignment: .trailing, spacing: 3) {
                        if let trailing { Text(trailing).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary) }
                        if let trailingMeta { Text(trailingMeta).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued) }
                    }
                }
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

// MARK: - The Glance — adaptive: all-clear (A) when nothing's due, "what's coming" (B) as items approach

struct GlanceView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var units: Units
    @State private var selected: Reminder?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            KoiColors.surface.ignoresSafeArea()
            if garage.isAllClear {
                directionA.transition(.opacity)
            } else {
                directionB.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: garage.isAllClear)
        .sheet(item: $selected) { r in
            ReminderDetailView(reminder: r)
                .environmentObject(garage)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.disabled)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: header (shared)
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting).koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                Text(dateLine).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            Spacer()
            KoiIconButton(systemName: Ph.gear, accessibilityLabel: "Settings") { showSettings = true }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Direction A — the calm glance
    // The whole page scrolls together (header included) so the hero never clips, with the native
    // bounce; the minHeight keeps the hero centred when everything fits on one screen.
    private var directionA: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    VStack(spacing: 24) {
                        hero
                        statBand
                        VStack(spacing: 12) {
                            if let r = garage.nextHorizon { reminderCardButton(r, eyebrow: "Next up") }
                            lastFillCard
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, KoiSpace.s2)
                .padding(.bottom, KoiSpace.s4)
                .frame(minHeight: geo.size.height)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            RippleMark(size: 44, color: heroAccent.text)
            Text("All clear").koiStyle(.allClearHero).foregroundStyle(KoiColors.textPrimary)
            Text(heroSubtitle)
                .koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { Bloom(color: heroAccent.tile).offset(y: -24) }
    }

    // Subtle per-car accent — the hero glow + mark take the active car's hue, so you feel
    // which car you're looking at without a loud indicator.
    private var heroAccent: CarAccent { garage.activeCar?.accent ?? .sage }

    // The reassurance line adapts to the car: a plan with a mileage cap leads with the month's
    // mileage; otherwise the calm default.
    private var heroSubtitle: String { "Nothing due in the next few weeks." }

    // MARK: This-month stat band — three quiet numbers for the active car, in both states
    private struct BandStat { var value: String; var unit: String; var arrow: String?; var arrowColor: Color = KoiColors.textSubdued }

    @ViewBuilder private var statBand: some View {
        if let stats = fleetStats {
            VStack(spacing: 14) {
                Eyebrow(text: bandTitle)
                HStack(alignment: .top, spacing: 0) {
                    bandStat(stats.0)
                    bandDivider
                    bandStat(stats.1)
                }
            }
            .frame(maxWidth: .infinity)            // centre the whole stat block
            .padding(.vertical, 10)                // give it room to breathe
        }
    }

    /// No car selector — the Home is all your cars. One car needs no scope; several read as the fleet.
    private var bandTitle: String {
        garage.residents.count <= 1 ? "This month" : "Across your cars"
    }

    private var bandDivider: some View {
        Rectangle().fill(KoiColors.hairline).frame(width: 1, height: 34).padding(.horizontal, 22)
    }

    private func bandStat(_ s: BandStat) -> some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(s.value).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                if let a = s.arrow { Text(a).koiStyle(.meta).foregroundStyle(s.arrowColor) }
            }
            Text(s.unit).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
        }
        .fixedSize()   // hug content so the two stats centre as a group
    }

    /// All-cars totals — the two numbers worth a glance: distance / month and running cost / month.
    /// (cost-per-distance is just their ratio, so it lives in the car's full insights, not here.)
    private var fleetStats: (BandStat, BandStat)? {
        let km = garage.fleetDistancePerMonth()
        let cost = garage.fleetRunningCostPerMonth()
        guard km != nil || cost != nil else { return nil }
        let distance = BandStat(
            value: km.map { units.distanceValue($0).formatted(.number.grouping(.automatic)) } ?? "—",
            unit: "\(units.distanceUnit) / month")
        let monthly = BandStat(
            value: cost.map { "≈" + $0.formatted(.currency(code: units.currencyCode).precision(.fractionLength(0))) } ?? "—",
            unit: "/ month")
        return (distance, monthly)
    }

    // MARK: Direction B — what's coming
    private var directionB: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                statBand
                Text(comingUpLine)
                    .koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let featured = garage.comingUp.first { featuredCard(featured) }

                let rest = Array(garage.sortedReminders.dropFirst())
                if !rest.isEmpty {
                    Eyebrow(text: "Also coming up").padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(rest.enumerated()), id: \.element.id) { idx, r in
                            Button { selected = r } label: {
                                reminderRow(r, last: idx == rest.count - 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .koiCard(padding: 0)
                }
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.vertical, KoiSpace.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var comingUpLine: String {
        // No car name — the reminders below already say which car. Just the shape of what's ahead.
        switch garage.comingUp.count {
        case 1:  return "One thing coming up."
        case 2:  return "A couple of things coming up."
        default: return "A few things coming up."
        }
    }

    private func featuredCard(_ r: Reminder) -> some View {
        Button { selected = r } label: {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Next up")
                HStack(spacing: 12) {
                    IconTile(systemName: r.kind.icon, tint: garage.urgency(r).tile)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary).lineLimit(1)
                        Text(r.detail).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                HStack {
                    Spacer()
                    Text(garage.countdown(r)).koiStyle(.monoMd).foregroundStyle(garage.urgency(r).countdownColor)
                }
            }
            .koiCard(fill: KoiColors.ochreTint)
        }
        .buttonStyle(.plain)
    }

    private func reminderRow(_ r: Reminder, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(systemName: r.kind.icon, tint: garage.urgency(r).tile)
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary).lineLimit(1)
                    Text(r.detail).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued).lineLimit(1)
                }
                Spacer(minLength: 10)
                Text(garage.countdown(r)).koiStyle(.monoSm).foregroundStyle(garage.urgency(r).countdownColor)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            .padding(14)
            if !last {
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14)
            }
        }
    }

    // MARK: cards (Direction A)
    private func reminderCardButton(_ r: Reminder, eyebrow: String) -> some View {
        Button { selected = r } label: {
            GlanceCard(eyebrow: eyebrow, icon: r.kind.icon, tint: garage.urgency(r).tile,
                       title: r.title, subtitle: r.detail, trailing: garage.countdown(r))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var lastFillCard: some View {
        if let latest = garage.latestFill() {
            GlanceCard(eyebrow: "Last fill-up", icon: "gauge.medium", tint: .sage,
                       title: KoiFormat.money(latest.log.amount, code: latest.log.currency), titleMono: true,
                       subtitle: lastFillSubtitle(latest.log, car: latest.car),
                       trailing: lastFillPerLiter(latest.log))
        }
    }

    private func lastFillPerLiter(_ log: FuelLog) -> String? {
        guard log.liters > 0 else { return nil }
        return KoiFormat.pricePerLiter((log.amount as NSDecimalNumber).doubleValue / log.liters)
    }
    private func lastFillSubtitle(_ log: FuelLog, car: Car) -> String {
        var parts: [String] = [car.displayName]
        if let e = garage.efficiencyL100(for: log) { parts.append(units.economyText(e)) }
        parts.append(KoiFormat.shortDate(log.date))
        return parts.joined(separator: " · ")
    }
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }
    private var dateLine: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

#Preview("All clear") {
    GlanceView().environmentObject(Garage(persists: false))
}
#Preview("Coming up") {
    GlanceView().environmentObject(Garage.preview)
}
