import Foundation

enum ReminderKind: String, Codable, CaseIterable {
    case service, inspection, insurance, mileageCap

    /// SF Symbols placeholders for Lucide wrench / shield-check / umbrella / progress.
    var icon: String {
        switch self {
        case .service:    return "wrench.adjustable"
        case .inspection: return "checkmark.seal"
        case .insurance:  return "umbrella"
        case .mileageCap: return "chart.bar"
        }
    }
}

/// How close a reminder is. Drives colour: neutral → ochre (coming up) → red (overdue).
/// Red is earned, never used on a resting screen.
enum Urgency {
    case neutral, comingUp, overdue
    var rank: Int { self == .overdue ? 0 : (self == .comingUp ? 1 : 2) }
}

/// A "coming up" item. Either date-based (inspection/insurance/service-by-date),
/// mileage-based (service due at an odometer target), or a monthly mileage-cap gauge.
struct Reminder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var kind: ReminderKind
    var title: String
    var detail: String
    var dueDate: Date?
    var dueMileageKm: Int?     // absolute odometer target (service-by-mileage)
    var monthlyUsedKm: Int?    // mileage-cap progress
    var monthlyCapKm: Int?     // mileage-cap target
    var snoozedUntil: Date?
    var resolved: Bool = false
}
