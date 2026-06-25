import Foundation

/// The two relationships the user sees. "On a plan" then splits into a monthly plan
/// or financing, not a top-level choice.
enum Relationship: String, CaseIterable, Identifiable {
    case own, plan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .own:  return "Own it"
        case .plan: return "On a plan"
        }
    }

    var subtitle: String {
        switch self {
        case .own:  return "It’s yours, for as long as you like"
        case .plan: return "Paid for monthly, not bought outright"
        }
    }

    /// Phosphor glyphs (rendered by KoiIcon): house / calendar.
    var icon: String {
        switch self {
        case .own:  return Ph.house
        case .plan: return Ph.calendar
        }
    }
}
