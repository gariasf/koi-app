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
            .overlay(Image(systemName: systemName).font(.system(size: 18, weight: .regular)).foregroundStyle(tint.fg))
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
    @EnvironmentObject private var fuel: FuelPriceStore
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
        .task { await fuel.refresh(province: garage.activeCar?.fuelRegionID) }
        .sheet(item: $selected) { r in
            ReminderDetailView(reminder: r)
                .environmentObject(garage)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(fuel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: header (shared)
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting).koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                    Text(dateLine).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(KoiColors.textSubdued)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            Menu {
                ForEach(garage.residents) { c in
                    Button {
                        garage.setActiveCar(c.id)
                        Task { await fuel.refresh(province: c.fuelRegionID) }
                    } label: {
                        if c.id == garage.activeCar?.id {
                            Label(c.displayName, systemImage: "checkmark")
                        } else {
                            Text(c.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(KoiColors.sage).frame(width: 9, height: 9)
                    Text(activeCarLine).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                    if garage.residents.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KoiColors.textSubdued)
                    }
                }
            }
            .disabled(garage.residents.count <= 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Direction A — the calm glance
    private var directionA: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            hero
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                if let r = garage.nextHorizon { reminderCardButton(r, eyebrow: "Next up") }
                lastFillCard
                dieselCard
            }
            .padding(.bottom, KoiSpace.s4)   // breathing room above the tab bar / ＋ Log
        }
        .padding(.horizontal, KoiSpace.gutter)
        .padding(.top, KoiSpace.s2)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            RippleMark(size: 44)
            Text("All clear").koiStyle(.allClearHero).foregroundStyle(KoiColors.textPrimary)
            Text("Nothing due for the next six weeks.")
                .koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { Bloom().offset(y: -24) }
    }

    // MARK: Direction B — what's coming
    private var directionB: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
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
        let car = garage.comingUpHeadlineCar?.displayName ?? "your garage"
        return "A few things coming up — mostly \(car)."
    }

    private func featuredCard(_ r: Reminder) -> some View {
        Button { selected = r } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconTile(systemName: r.kind.icon, tint: garage.urgency(r).tile)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next up · \(r.title)").koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary).lineLimit(1)
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
        if let car = garage.activeCar, let log = garage.latestFuelLog(for: car) {
            GlanceCard(eyebrow: "Last fill-up", icon: "drop.fill", tint: .sage,
                       title: lastFillTitle(log), titleMono: true, subtitle: lastFillSubtitle(log))
        } else {
            GlanceCard(eyebrow: "Last fill-up", icon: "drop.fill", tint: .sage,
                       title: "No fill-ups yet", subtitle: "Tap ＋ to log your first")
        }
    }

    // Live local fuel price (minetur feed) — tap to pick region.
    @ViewBuilder private var dieselCard: some View {
        Button { showSettings = true } label: {
            if let s = fuel.cheapest, let price = fuel.product.price(s) {
                GlanceCard(eyebrow: fuel.product.nearbyEyebrow, icon: "mappin", tint: .sage,
                           title: KoiFormat.pricePerLiter(price), titleMono: true,
                           subtitle: "\(s.brand) · \(s.municipality)",
                           trailingMeta: fuel.freshnessText.isEmpty ? nil : fuel.freshnessText)
            } else {
                GlanceCard(eyebrow: "Fuel nearby", icon: "mappin", tint: .sage,
                           title: "Pick your region", subtitle: "Set a province to see live prices")
            }
        }
        .buttonStyle(.plain)
    }

    private func lastFillTitle(_ log: FuelLog) -> String {
        let money = KoiFormat.money(log.amount, code: log.currency)
        if let e = garage.efficiencyL100(for: log) { return "\(money) · \(KoiFormat.efficiency(e))" }
        return money
    }
    private func lastFillSubtitle(_ log: FuelLog) -> String {
        [KoiFormat.shortDate(log.date), log.station].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: derived copy
    private var activeCarLine: String {
        guard let car = garage.activeCar else { return "No active car" }
        if let plan = garage.plan(for: car), let provider = plan.provider, !provider.isEmpty {
            return "\(car.displayName) · \(provider)"
        }
        return car.displayName
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
    GlanceView().environmentObject(Garage(persists: false)).environmentObject(FuelPriceStore.preview)
}
#Preview("Coming up") {
    GlanceView().environmentObject(Garage.preview).environmentObject(FuelPriceStore.preview)
}
