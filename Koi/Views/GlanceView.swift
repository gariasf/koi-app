import SwiftUI
import UIKit

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
    @EnvironmentObject private var location: LocationProvider
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
        .task { if fuel.available { await fuel.refresh() } }
        .onChange(of: location.provinceName) { _, name in
            // a fresh fix tells us the province — let the fuel feed follow the user (Spain only)
            if fuel.available, let name, let p = Province.match(name), p.id != fuel.provinceID {
                fuel.setProvince(p.id)
                Task { await fuel.refresh() }
            }
        }
        .sheet(item: $selected) { r in
            ReminderDetailView(reminder: r)
                .environmentObject(garage)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(fuel)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.disabled)
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
                KoiIconButton(systemName: "gearshape", accessibilityLabel: "Settings") { showSettings = true }
            }
            Menu {
                ForEach(garage.residents) { c in
                    Button {
                        garage.setActiveCar(c.id)
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
                        VStack(spacing: 12) {
                            if let r = garage.nextHorizon { reminderCardButton(r, eyebrow: "Next up") }
                            lastFillCard
                            fuelCard
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
    private var heroSubtitle: String {
        if let car = garage.activeCar, let plan = garage.plan(for: car), plan.kind != .owned,
           let cap = plan.mileageCapPerMonth, cap > 0, let used = garage.kmThisCycle(for: car) {
            return "\(used.formatted()) of \(cap.formatted()) km this \(plan.capPeriod.noun)."
        }
        return "Nothing due in the next few weeks."
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
        let items = garage.comingUp
        let name = garage.comingUpHeadlineCar?.displayName ?? "your car"
        if items.count == 1 { return "One thing coming up for \(name)." }
        let cars = Set(items.map { $0.carID })
        if cars.count <= 1 {
            return items.count == 2
                ? "A couple of things coming up for \(name)."
                : "A few things coming up for \(name)."
        }
        // multiple cars — only say "mostly" when one car holds a strict majority
        let topID = garage.comingUpHeadlineCar?.id
        let topCount = items.filter { $0.carID == topID }.count
        return topCount * 2 > items.count
            ? "A few things coming up, mostly \(name)."
            : "A few things coming up across your cars."
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
        if garage.activeCar?.fuel.nearbyProduct != nil {   // petrol/diesel only — matches the nearby card
            if let car = garage.activeCar, let log = garage.latestFuelLog(for: car) {
                GlanceCard(eyebrow: "Last fill-up", icon: "gauge.medium", tint: .sage,
                           title: KoiFormat.money(log.amount, code: log.currency), titleMono: true,
                           subtitle: lastFillSubtitle(log),
                           trailing: lastFillPerLiter(log))
            } else {
                GlanceCard(eyebrow: "Last fill-up", icon: "gauge.medium", tint: .sage,
                           title: "No fill-ups yet", subtitle: "Log your first one to see it here")
            }
        }
    }

    // Local fuel price for the active car's fuel (minetur feed). Hidden for electric / gas.
    // Undecided → ask for location; located → the closest station (tap = directions);
    // denied / no fix → region price as info only (no directions).
    @ViewBuilder private var fuelCard: some View {
        if fuel.available, let product = garage.activeCar?.fuel.nearbyProduct {
            if location.status == .notDetermined {
                Button { location.requestOrRefresh() } label: {
                    GlanceCard(eyebrow: product.nearbyEyebrow, icon: "fuelpump.fill", tint: .sage,
                               title: "Find fuel near you", subtitle: "Tap to use your location, only while open")
                }
                .buttonStyle(.plain)
            } else if location.isAuthorized, let coord = location.coordinate,
                      let near = fuel.closest(to: coord, product: product), let price = product.price(near.station) {
                Button { openDirections(to: near.station) } label: {
                    GlanceCard(eyebrow: product.nearbyEyebrow, icon: "fuelpump.fill", tint: .sage,
                               title: KoiFormat.pricePerLiter(price), titleMono: true,
                               subtitle: "\(near.station.brand) · \(near.station.municipality)",
                               trailingMeta: KoiFormat.distance(near.distanceKm))
                }
                .buttonStyle(.plain)
            } else if let s = fuel.cheapest(product: product), let price = product.price(s) {
                // fallback — region price as information only, no directions to a specific station
                GlanceCard(eyebrow: product.nearbyEyebrow, icon: "fuelpump.fill", tint: .sage,
                           title: KoiFormat.pricePerLiter(price), titleMono: true,
                           subtitle: "Cheapest in \(fuel.provinceName)",
                           trailingMeta: fuel.freshnessText.isEmpty ? nil : fuel.freshnessText)
            } else {
                Button { showSettings = true } label: {
                    GlanceCard(eyebrow: product.nearbyEyebrow, icon: "fuelpump.fill", tint: .sage,
                               title: "No prices yet", subtitle: "Set your region in Settings for local prices")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openDirections(to s: FuelStation) {
        // validate coordinates fall within Europe before trusting them in a Maps URL
        guard let lat = s.latitude, let lon = s.longitude,
              (34.0...72.0).contains(lat), (-25.0...45.0).contains(lon) else { showSettings = true; return }
        let dest = "\(lat),\(lon)"
        if let google = URL(string: "comgooglemaps://?daddr=\(dest)&directionsmode=driving"),
           UIApplication.shared.canOpenURL(google) {
            UIApplication.shared.open(google)
        } else if let apple = URL(string: "http://maps.apple.com/?daddr=\(dest)") {
            UIApplication.shared.open(apple)
        }
    }

    private func lastFillPerLiter(_ log: FuelLog) -> String? {
        guard log.liters > 0 else { return nil }
        return KoiFormat.pricePerLiter((log.amount as NSDecimalNumber).doubleValue / log.liters)
    }
    private func lastFillSubtitle(_ log: FuelLog) -> String {
        var parts: [String] = []
        if let e = garage.efficiencyL100(for: log) { parts.append(KoiFormat.efficiency(e)) }
        parts.append(KoiFormat.shortDate(log.date))
        return parts.joined(separator: " · ")
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
