import Foundation

/// The only three relationships the user sees. One answer sets sensible defaults;
/// lease/finance/subscription are presets of "On a plan", not top-level choices.
enum Relationship: String, CaseIterable, Identifiable {
    case own, plan, borrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .own:    return "Own it"
        case .plan:   return "On a plan"
        case .borrow: return "Borrowing"
        }
    }

    var subtitle: String {
        switch self {
        case .own:    return "It's yours — kept for as long as you like"
        case .plan:   return "Lease, finance or subscription — monthly, with a mileage cap"
        case .borrow: return "A rental or loan car — a short guest that retires when returned"
        }
    }

    /// SF Symbols placeholders for Lucide home / calendar / clock.
    var icon: String {
        switch self {
        case .own:    return "house"
        case .plan:   return "calendar"
        case .borrow: return "clock"
        }
    }
}
