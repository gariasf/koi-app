import SwiftUI

/// Car detail — owned. Everything about this car; plan layer invisible; no Swap.
struct CarDetailView: View {
    @EnvironmentObject private var garage: Garage
    @Environment(\.dismiss) private var dismiss
    let car: Car
    @State private var showLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                backRow
                car.accent.tile
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: KoiRadius.card, style: .continuous))
                header
                actions
                timeline
            }
            .padding(.horizontal, KoiSpace.gutter)
            .padding(.bottom, 24)
        }
        .background(KoiColors.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLog) {
            LogSheetView(car: car)
                .environmentObject(garage)
                .presentationDragIndicator(.visible)
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
            if let year = car.year {
                Text("owned since \(String(year))").koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
            }
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionTile("Log", "square.and.pencil") { showLog = true }
            actionTile("Remind", "bell") { }
            actionTile("Docs", "folder") { }
            actionTile("Edit", "pencil") { }
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

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Timeline")
            let logs = Array(garage.fuelLogs(for: car).reversed())   // newest first
            if logs.isEmpty {
                Text("No events yet. Log a fill-up to start the timeline.")
                    .koiStyle(.body).foregroundStyle(KoiColors.textSubdued)
            } else {
                ForEach(Array(logs.enumerated()), id: \.element.id) { idx, log in
                    TimelineRow(title: timelineTitle(log),
                                subtitle: timelineSubtitle(log),
                                isLast: idx == logs.count - 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    NavigationStack { CarDetailView(car: Garage.preview.residents.first!) }
        .environmentObject(Garage.preview)
}
