import SwiftUI

/// Past mileage cap cycles — "did I stay under last month, and the months before?" A calm,
/// read-only list: the live cycle sits on top (marked), earlier ones below. Derived from your
/// odometer readings, so months without a reading simply don't appear.
struct MileageHistoryView: View {
    @EnvironmentObject private var garage: Garage
    let car: Car

    private var cycles: [Garage.MileageCycleSummary] { garage.mileageHistory(for: car) }
    private var periodNoun: String { garage.plan(for: car)?.capPeriod.noun ?? "month" }
    private var yearly: Bool { garage.plan(for: car)?.capPeriod == .year }

    var body: some View {
        VStack(spacing: 0) {
            ModalHeader(title: "Mileage history")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if cycles.isEmpty {
                        EmptyHint(icon: "chart.bar",
                                  text: "No mileage history yet. Update your odometer over time and your \(periodNoun)ly totals show up here.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(cycles.enumerated()), id: \.element.id) { idx, c in
                                row(c, last: idx == cycles.count - 1)
                            }
                        }
                        .koiCard(padding: 0)
                        Text("Based on your odometer readings. \(yearly ? "Years" : "Months") without a reading are left out.")
                            .koiStyle(.meta).foregroundStyle(KoiColors.textFaint)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    private func row(_ c: Garage.MileageCycleSummary, last: Bool) -> some View {
        let over = c.used > c.cap
        let frac = c.cap > 0 ? min(1, Double(c.used) / Double(c.cap)) : 0
        let color: Color = over ? KoiColors.red : (frac >= 0.8 ? KoiColors.ochre : KoiColors.sage)
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(periodLabel(c)).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary)
                    if c.isCurrent {
                        Text("This \(periodNoun)").koiStyle(.meta).foregroundStyle(KoiColors.sageText)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(KoiColors.sageTint, in: Capsule())
                    }
                    Spacer(minLength: 8)
                    Text("\(c.used.formatted()) / \(c.cap.formatted()) km")
                        .koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(KoiColors.insetFill)
                        Capsule().fill(color).frame(width: max(6, geo.size.width * frac))
                    }
                }
                .frame(height: 8)
                Text(footnote(c, over: over))
                    .koiStyle(.meta).foregroundStyle(over ? KoiColors.red : KoiColors.textSubdued)
            }
            .padding(14)
            if !last {
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14)
            }
        }
    }

    private func periodLabel(_ c: Garage.MileageCycleSummary) -> String {
        yearly ? c.start.formatted(.dateTime.year())
               : c.start.formatted(.dateTime.month(.wide).year())
    }

    private func footnote(_ c: Garage.MileageCycleSummary, over: Bool) -> String {
        over ? "\((c.used - c.cap).formatted()) km over"
             : "\(max(0, c.cap - c.used).formatted()) km under"
    }
}

#Preview {
    MileageHistoryView(car: Garage.preview.residents.last!)
        .environmentObject(Garage.preview)
}
