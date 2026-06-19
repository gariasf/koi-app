import SwiftUI

/// The Story — a calm, cross-car history of everything that has happened: fill-ups, costs,
/// services, a car joining or being swapped, insurance starting. Read-only projection over the
/// data the garage already holds (see `TimelineEvent`); grouped by month, newest first.
struct TimelineView: View {
    @EnvironmentObject private var garage: Garage

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, KoiSpace.s3)
                .padding(.bottom, KoiSpace.s1)
            content
        }
        .background(KoiColors.surface.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("Story").koiStyle(.pageTitle).foregroundStyle(KoiColors.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var content: some View {
        let events = garage.timeline()
        if events.isEmpty {
            VStack {
                Spacer()
                EmptyHint(icon: "clock.arrow.circlepath",
                          text: "Your story starts with your first log. Fill-ups, costs and services land here.")
                    .padding(.horizontal, KoiSpace.gutter)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(months(events), id: \.key) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: group.key)
                            VStack(spacing: 0) {
                                ForEach(Array(group.events.enumerated()), id: \.element.id) { idx, ev in
                                    eventRow(ev, last: idx == group.events.count - 1)
                                }
                            }
                            .koiCard(padding: 0)
                        }
                    }
                }
                .padding(.horizontal, KoiSpace.gutter)
                .padding(.top, KoiSpace.s2)
                .padding(.bottom, KoiSpace.s4)
            }
        }
    }

    private func eventRow(_ ev: TimelineEvent, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(systemName: ev.icon, tint: ev.tint)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if garage.residents.count > 1, let accent = garage.car(ev.carID)?.accent {
                            Circle().fill(accent.text).frame(width: 7, height: 7)
                        }
                        Text(ev.title).koiStyle(.listTitle).foregroundStyle(KoiColors.textPrimary).lineLimit(1)
                    }
                    if let s = ev.subtitle {
                        Text(s).koiStyle(.meta).foregroundStyle(KoiColors.textSubdued).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    if let t = ev.trailing {
                        Text(t).koiStyle(.monoSm).foregroundStyle(KoiColors.textPrimary)
                    }
                    Text(ev.date.formatted(.dateTime.day().month(.abbreviated)))
                        .koiStyle(.meta).foregroundStyle(KoiColors.textSubdued)
                }
            }
            .padding(14)
            if !last {
                Rectangle().fill(KoiColors.hairline).frame(height: 1).padding(.leading, 14)
            }
        }
    }

    // MARK: month grouping
    private struct MonthGroup { let key: String; let events: [TimelineEvent] }

    private func months(_ events: [TimelineEvent]) -> [MonthGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: events) { cal.dateComponents([.year, .month], from: $0.date) }
        let thisYear = cal.component(.year, from: Date())
        return groups.keys
            .sorted { (cal.date(from: $0) ?? .distantPast) > (cal.date(from: $1) ?? .distantPast) }
            .map { comps in
                let date = cal.date(from: comps) ?? Date()
                let style: Date.FormatStyle = (comps.year == thisYear)
                    ? .dateTime.month(.wide) : .dateTime.month(.wide).year()
                return MonthGroup(key: date.formatted(style), events: groups[comps] ?? [])
            }
    }
}

#Preview { TimelineView().environmentObject(Garage.preview) }
