import SwiftUI

// MARK: - Shared Glance building blocks (used across several screens)

enum GlanceTint {
    case neutral, sage, ochre

    var bg: Color {
        switch self {
        case .neutral: return KoiColors.insetFill
        case .sage:    return KoiColors.sageTint
        case .ochre:   return KoiColors.ochreTint
        }
    }
    var fg: Color {
        switch self {
        case .neutral: return KoiColors.textSecondary
        case .sage:    return KoiColors.sage
        case .ochre:   return KoiColors.ochre
        }
    }
}

/// NOTE: SF Symbols are scaffold placeholders. The handoff specifies Lucide icons
/// (1.5–1.6px stroke, rounded). Production must bundle Lucide and swap these.
struct IconTile: View {
    let systemName: String
    var tint: GlanceTint = .neutral

    var body: some View {
        RoundedRectangle(cornerRadius: KoiRadius.tile, style: .continuous)
            .fill(tint.bg)
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(tint.fg)
            )
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).koiStyle(.eyebrow).foregroundStyle(KoiColors.textSubdued)
    }
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
                    Text(title)
                        .koiStyle(titleMono ? .monoMd : .listTitle)
                        .foregroundStyle(KoiColors.textPrimary)
                    Text(subtitle)
                        .koiStyle(.meta)
                        .foregroundStyle(KoiColors.textSubdued)
                }
                Spacer(minLength: 8)
                if trailing != nil || trailingMeta != nil {
                    VStack(alignment: .trailing, spacing: 3) {
                        if let trailing {
                            Text(trailing).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                        }
                        if let trailingMeta {
                            Text(trailingMeta).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                        }
                    }
                }
            }
        }
        .koiCard()
    }
}

// MARK: - Glance · Direction A ("the calm glance" / all-clear state)

struct GlanceAllClearView: View {
    @EnvironmentObject private var garage: Garage

    var body: some View {
        ZStack {
            KoiColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                hero
                Spacer(minLength: 8)
                cards
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.top, KoiSpace.s2)
            .padding(.bottom, KoiSpace.s2)
        }
    }

    // greeting + date + active car (real, from the store)
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting).koiStyle(.glanceLine).foregroundStyle(KoiColors.textPrimary)
                Text(dateLine).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            HStack(spacing: 8) {
                Circle().fill(KoiColors.sage).frame(width: 9, height: 9)
                Text(activeCarLine)
                    .koiStyle(.body)
                    .foregroundStyle(KoiColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // breathing bloom behind ripple mark + "All clear" + calm sub
    private var hero: some View {
        VStack(spacing: 14) {
            RippleMark(size: 44)
            Text("All clear")
                .koiStyle(.allClearHero)
                .foregroundStyle(KoiColors.textPrimary)
            Text("Nothing due for the next six weeks.")
                .koiStyle(.body)
                .foregroundStyle(KoiColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { Bloom().offset(y: -24) }
    }

    private var cards: some View {
        VStack(spacing: 12) {
            // TODO (P6): real reminders engine.
            GlanceCard(eyebrow: "Next up", icon: "calendar", tint: .neutral,
                       title: "ITV inspection", subtitle: "Biennial roadworthiness check",
                       trailing: "14 Aug", trailingMeta: "in 9 weeks")
            lastFillCard   // real, from the store
            // TODO (P8): live Spain fuel-price feed.
            GlanceCard(eyebrow: "Diesel nearby", icon: "mappin", tint: .sage,
                       title: "€1.42 /L", titleMono: true,
                       subtitle: "Repsol, Av. de Burgos · 800 m",
                       trailingMeta: "2h ago")
        }
    }

    @ViewBuilder private var lastFillCard: some View {
        if let car = garage.activeCar, let log = garage.latestFuelLog(for: car) {
            GlanceCard(eyebrow: "Last fill-up", icon: "drop.fill", tint: .sage,
                       title: lastFillTitle(log), titleMono: true,
                       subtitle: lastFillSubtitle(log))
        } else {
            GlanceCard(eyebrow: "Last fill-up", icon: "drop.fill", tint: .sage,
                       title: "No fill-ups yet", subtitle: "Tap ＋ to log your first")
        }
    }

    private func lastFillTitle(_ log: FuelLog) -> String {
        let money = KoiFormat.money(log.amount, code: log.currency)
        if let e = garage.efficiencyL100(for: log) {
            return "\(money) · \(KoiFormat.efficiency(e))"
        }
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

#Preview("Glance · light") { GlanceAllClearView().environmentObject(Garage.preview).preferredColorScheme(.light) }
#Preview("Glance · dark")  { GlanceAllClearView().environmentObject(Garage.preview).preferredColorScheme(.dark) }
