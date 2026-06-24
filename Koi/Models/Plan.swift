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
        case .subscription: return "Plan"
        }
    }
}

struct Plan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: PlanKind
    var provider: String?
    var monthlyCost: Decimal?
    var initialPayment: Decimal?   // deposit / down-payment / entrada paid up front (not a purchase)
    var mileageCapPerMonth: Int?       // the cap amount, for the interval in `mileageCapPeriod`
    var mileageCapPeriod: CapPeriod?   // how often the cap resets (defaults to monthly)
    var mileagePools: Bool?            // unused km roll forward to end of term (odo read at return)
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
    var capPeriod: CapPeriod { mileageCapPeriod ?? .month }
}

/// How often a mileage cap resets. A monthly plan resets every month; a lease-style cap can be yearly.
enum CapPeriod: String, Codable, CaseIterable, Identifiable {
    case month, year
    var id: String { rawValue }
    var months: Int { self == .year ? 12 : 1 }
    var noun: String { self == .year ? "year" : "month" }   // "Mileage this month" / "this year"
    var unit: String { self == .year ? "km/yr" : "km/mo" }
    var label: String { self == .year ? "Yearly" : "Monthly" }
}
