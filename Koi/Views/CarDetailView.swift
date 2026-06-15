import SwiftUI

/// Car detail. Owned → plan layer invisible, action is Edit. On a plan that allows it →
/// the 4th action becomes Swap car, and a plan card + lineage appear.
struct CarDetailView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car
    @State private var showLog = false
    @State private var showSwap = false
    @State private var showVault = false
    @State private var showEdit = false

    private var plan: Plan? { garage.plan(for: car) }
    private var canSwap: Bool { plan?.allowsSwap == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backRow
                CarPhotoTile(car: car, height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
                header
                actions
                planCard
                timeline
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.bottom, 24)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLog) {
            LogSheetView(car: car).environmentObject(garage).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVault) {
            InsuranceVaultView(car: car).environmentObject(garage).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEdit) {
            EditCarView(car: car).environmentObject(garage).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSwap) {
            if let plan {
                NavigationStack {
                    AddSwapCarView(plan: plan, currentCar: car) { showSwap = false }
                        .environmentObject(garage)
                }
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var backRow: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .medium))
                    Text("Garage").koiStyle(.body)
                }
                .foregroundStyle(KoiColors.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Button { showEdit = true } label: {
                Text("Edit").koiStyle(.body).foregroundStyle(KoiColors.sageText)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(car.displayName).koiStyle(.carName).foregroundStyle(KoiColors.textPrimary)
                    Text(car.subtitle).koiStyle(.body).foregroundStyle(KoiColors.textSecondary)
                }
                Spacer(minLength: 8)
                statusPill
            }
            metaRow
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(KoiColors.sage).frame(width: 7, height: 7)
            Text("All good").koiStyle(.meta).foregroundStyle(KoiColors.sageText)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(KoiColors.sageTint, in: Capsule())
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            if let plate = car.plate, !plate.isEmpty {
                Text(plate).koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(KoiColors.insetFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            if let odo = car.odometerKm {
                Text(KoiFormat.km(odo)).koiStyle(.monoSm).foregroundStyle(KoiColors.textSecondary)
            }
            Text(sinceText).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            Spacer(minLength: 0)
        }
    }

    private var sinceText: String {
        if let plan, plan.kind != .owned {
            return "since \(plan.startedAt.formatted(.dateTime.month(.abbreviated).year()))"
        }
        if let year = car.year { return "owned since \(String(year))" }
        return "owned"
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionTile("Log", "square.and.pencil") { showLog = true }
            actionTile("Remind", "bell") { }
            actionTile("Docs", "folder") { showVault = true }
            if canSwap {
                actionTile("Swap", "arrow.triangle.2.circlepath") { showSwap = true }
            }
        }
    }

    private func actionTile(_ label: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(KoiColors.textPrimary)
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

    @ViewBuilder private var planCard: some View {
        if let plan, plan.kind != .owned {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: plan.kind.label)
                Text(planLine(plan)).koiStyle(.monoMd).foregroundStyle(KoiColors.textPrimary)
                if let end = plan.endsAt {
                    Text("Until \(end.formatted(.dateTime.month(.abbreviated).year()))")
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
                if plan.allowsSwap {
                    Text(swapText(plan))
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .koiCard()
        }
    }

    private func planLine(_ plan: Plan) -> String {
        var parts: [String] = []
        if let p = plan.provider, !p.isEmpty { parts.append(p) }
        if let m = plan.monthlyCost { parts.append(KoiFormat.money(m) + "/mo") }
        if let cap = plan.mileageCapPerMonth { parts.append("\(cap) km/mo cap") }
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
                Text("No events yet. Log a fill-up to start the timeline.")
                    .koiStyle(.body).foregroundStyle(KoiColors.textSubdued)
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
        for log in garage.fuelLogs(for: car) {
            items.append(TLItem(date: log.date, title: timelineTitle(log), subtitle: timelineSubtitle(log)))
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
        }
        return items.sorted { $0.date > $1.date }
    }

    private func timelineTitle(_ log: FuelLog) -> String {
        let money = KoiFormat.money(log.amount, code: log.currency)
        if let e = garage.efficiencyL100(for: log) {
            return "Fuel \(money) · \(KoiFormat.efficiency(e))"
        }
        return "Fuel \(money)"
    }

    private func timelineSubtitle(_ log: FuelLog) -> String {
        [KoiFormat.shortDate(log.date), log.station].compactMap { $0 }.joined(separator: " · ")
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
}
