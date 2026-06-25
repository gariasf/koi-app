import Foundation

/// Non-fuel log entries (expense / service / note). Fuel keeps its own `FuelLog`
/// because efficiency derives from it.
enum LogKind: String, Codable, CaseIterable {
    case expense, service, note

    var label: String {
        switch self {
        case .expense: return "Expense"
        case .service: return "Service"
        case .note:    return "Note"
        }
    }
    /// Phosphor glyphs (rendered by KoiIcon): credit-card / wrench / note-pencil.
    var icon: String {
        switch self {
        case .expense: return Ph.card
        case .service: return Ph.wrench
        case .note:    return Ph.note
        }
    }
}

struct LogEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var kind: LogKind
    var date: Date = Date()
    var amount: Decimal?
    var note: String = ""
    var odometerKm: Int?
}
