import Foundation

/// The paid arrangement. Lease/finance/subscription share one shape; owned is an
/// invisible plan. A subscription can hold a *sequence* of swappable cars (lineage).
enum PlanKind: String, Codable, CaseIterable {
    case owned, lease, finance, subscription

    /// Swap is a capability of the plan, not a default action. Subscriptions allow it.
    var allowsSwapByDefault: Bool { self == .subscription }

    var label: String {
        switch self {
        case .owned:        return "Owned"
        case .lease:        return "Lease"
        case .finance:      return "Finance"
        case .subscription: return "Subscription"
        }
    }
}

struct Plan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: PlanKind
    var provider: String?
    var monthlyCost: Decimal?
    var mileageCapPerMonth: Int?
    var startedAt: Date = Date()
    var endsAt: Date?
    var includesInsurance: Bool = false
    var includesMaintenance: Bool = false
    var includesRoadside: Bool = false
    var allowsSwap: Bool = false
    var swapIntervalMonths: Int?   // e.g. 6 — only meaningful when allowsSwap

    /// Ordered lineage of cars that have occupied this plan; `.last` is current.
    var carIDs: [UUID] = []

    var currentCarID: UUID? { carIDs.last }
}
