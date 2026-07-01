import SwiftUI

/// "How it's going" in depth — the calm insights screen behind the car card's "See the full
/// picture ›". Cost breakdown, distance trend, and fuel-economy history, all derived.
struct InsightsView: View {
    @EnvironmentObject private var garage: Garage
    @EnvironmentObject private var units: Units
    let car: Car

    private func dbl(_ d: Decimal) -> Double { (d as NSDecimalNumber).doubleValue }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "How it's going")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(car.displayName).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                    spentSection
                    costSection
                    distanceSection
                    economySection
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    // MARK: spent + breakdown
    private var spentSection: some View {
        let b = garage.costBreakdown(for: car)
        let capitalLabel = (garage.plan(for: car)?.kind ?? .owned) == .owned ? "Purchase" : "Plan"
        let rows: [(String, Decimal, Color)] = [
            (capitalLabel, b.capital, KoiColors.textPrimary),
            ("Fuel", b.fuel, KoiColors.sage),
            ("Service", b.service, KoiColors.ochreText),
            ("Other", b.other, KoiColors.textSubdued),
        ].filter { $0.1 > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Spent so far")
            Text(units.money(garage.totalSpent(on: car))).koiStyle(.monoLg).foregroundStyle(KoiColors.textPrimary)
            SegmentBar(segments: rows.map { .init(value: dbl($0.1), color: $0.2, label: $0.0) })
            VStack(spacing: 7) {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 8) {
                        Circle().fill(row.2).frame(width: 8, height: 8)
                        Text(row.0).koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                        Spacer()
                        Text(units.money(row.1)).koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }

    // MARK: running cost (per month + per distance)
    @ViewBuilder private var costSection: some View {
        if let rc = garage.runningCost(for: car) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Running cost")
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("≈\(rc.perMonth.formatted(.currency(code: units.currencyCode).precision(.fractionLength(0))))/mo")
                        .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                    if let perKm = rc.perKm {
                        let perDist = units.distance == .km ? perKm : perKm * Decimal(1.609344)
                        Text(perDist.formatted(.currency(code: units.currencyCode).precision(.fractionLength(2))) + " / \(units.distanceUnit)")
                            .koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .koiCard()
        }
    }

    // MARK: distance trend
    private var distanceSection: some View {
        let series = garage.monthlyDistanceSeries(for: car).map(Double.init)
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Distance")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(garage.distanceThisYear(for: car).map { units.distanceText($0) } ?? "—")
                    .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                Text("this year").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            if let pm = garage.distancePerMonth(for: car) {
                Text("\(units.distanceText(pm)) / month on average").koiStyle(.meta).foregroundStyle(KoiColors.textSecondary)
            }
            if series.count > 1 {
                LineSparkline(values: series).frame(height: 64).padding(.top, 4)
            } else {
                Text("Not enough odometer history yet.").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }

    // MARK: economy history
    private var economySection: some View {
        let eco = garage.economySeries(for: car)
        let recent = garage.recentEconomy(for: car)
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Fuel economy")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(recent.map { units.economyText($0.l100) } ?? "—")
                    .koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                if let t = recent?.trend { Text(t.word).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued) }
            }
            if eco.count >= 2 {
                BarSparkline(values: Array(eco.suffix(8)), height: 56, barWidth: 9, spacing: 7).padding(.top, 4)
                HStack(spacing: 14) {
                    if let best = eco.min() { Text("best \(units.economyValue(best))").koiStyle(.meta).foregroundStyle(KoiColors.sageText) }
                    if let worst = eco.max() { Text("worst \(units.economyValue(worst))").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued) }
                    Spacer()
                    Text("last \(eco.suffix(8).count) fills").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            } else {
                Text("Log a couple of fills to see your economy here.").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .koiCard()
    }
}

#Preview {
    InsightsView(car: Garage.preview.residents.first!)
        .environmentObject(Garage.preview)
        .environmentObject(Units.preview)
}
