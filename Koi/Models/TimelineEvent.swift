import SwiftUI

/// A single past event in the Story — a read-only projection over everything the garage already
/// stores (fill-ups, expenses/service/notes, a car joining or being swapped, insurance starting).
/// No new persisted state: the Timeline is a view over the data, not a model of its own.
struct TimelineEvent: Identifiable {
    enum Kind { case fuel, expense, service, note, joined, swap, insurance }

    let id: String          // source-derived, stable across rebuilds
    let date: Date
    let carID: UUID
    let kind: Kind
    let title: String
    let subtitle: String?
    let trailing: String?   // mono amount, e.g. "61,40 €"

    var icon: String {
        switch kind {
        case .fuel:      return Ph.fuel
        case .expense:   return Ph.card
        case .service:   return Ph.wrench
        case .note:      return Ph.note
        case .joined:    return Ph.sparkle
        case .swap:      return Ph.swap
        case .insurance: return Ph.shield
        }
    }
    var tint: GlanceTint {
        switch kind {
        case .fuel, .joined, .insurance: return .sage
        case .service:                   return .ochre
        case .expense, .note, .swap:     return .neutral
        }
    }
}

extension Garage {
    /// The Story feed — every past event across the garage, newest first. Pass a car to scope it
    /// to one, or nil for all cars (the cross-car story is the point of the tab).
    func timeline(for car: Car? = nil) -> [TimelineEvent] {
        let scope = car?.id
        var events: [TimelineEvent] = []

        // Fill-ups — amount trailing, station + derived efficiency in the subtitle.
        for log in fuelLogs where scope == nil || log.carID == scope {
            let eff = efficiencyL100(for: log).map { KoiFormat.efficiency($0) }
            events.append(TimelineEvent(
                id: "fuel-\(log.id)", date: log.date, carID: log.carID, kind: .fuel,
                title: "Filled up",
                subtitle: joined([carLabel(log.carID, scope: scope), log.station, eff]),
                trailing: KoiFormat.money(log.amount, code: log.currency)))
        }

        // Expenses / service / notes.
        for e in logEntries where scope == nil || e.carID == scope {
            let kind: TimelineEvent.Kind = e.kind == .expense ? .expense
                : (e.kind == .service ? .service : .note)
            events.append(TimelineEvent(
                id: "entry-\(e.id)", date: e.date, carID: e.carID, kind: kind,
                title: e.note.isEmpty ? e.kind.label : e.note,
                subtitle: joined([carLabel(e.carID, scope: scope), e.note.isEmpty ? nil : e.kind.label]),
                trailing: e.amount.map { KoiFormat.money($0) }))
        }

        // A car joining the garage, and any later swap onto the same plan (lineage order).
        for plan in plans {
            for (idx, c) in lineage(for: plan).enumerated() where scope == nil || c.id == scope {
                let swapped = idx > 0
                events.append(TimelineEvent(
                    id: "join-\(c.id)", date: c.addedAt, carID: c.id,
                    kind: swapped ? .swap : .joined,
                    title: swapped ? "Swapped to \(c.displayName)" : "Added \(c.displayName)",
                    subtitle: swapped ? plan.provider.map { "\($0) plan" } : joinSubtitle(plan),
                    trailing: nil))
            }
        }

        // Insurance starting (one per policy).
        for p in policies where scope == nil || p.carID == scope {
            guard let from = p.validFrom else { continue }
            events.append(TimelineEvent(
                id: "ins-\(p.id)", date: from, carID: p.carID, kind: .insurance,
                title: "Insured with \(p.insurer)",
                subtitle: joined([carLabel(p.carID, scope: scope), p.coverage]),
                trailing: nil))
        }

        return events.sorted { $0.date > $1.date }
    }

    /// Only name the car in the all-cars view — when scoped to one car it's redundant.
    private func carLabel(_ id: UUID, scope: UUID?) -> String? {
        scope == nil ? car(id)?.displayName : nil
    }
    private func joinSubtitle(_ plan: Plan) -> String? {
        plan.kind == .owned ? "Owned" : (plan.provider.map { "\($0) · \(plan.kind.label)" } ?? plan.kind.label)
    }
    private func joined(_ parts: [String?]) -> String? {
        let kept = parts.compactMap { $0 }.filter { !$0.isEmpty }
        return kept.isEmpty ? nil : kept.joined(separator: " · ")
    }
}
