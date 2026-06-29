import Foundation

/// A fuel stop. Efficiency (L/100km) is *derived* from consecutive odometer readings,
/// never asked. Total + liters are the fill; odometer is optional (it's what unlocks the
/// derived efficiency — a fill logged without it still counts, it just doesn't pair up).
struct FuelLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var date: Date = Date()
    var amount: Decimal
    var currency: String = "EUR"
    var liters: Double
    var odometerKm: Int?       // optional — old logs decode their value; new logs may omit it
    var station: String?
    // Signals that keep derived L/100km honest. Optional so older saves + manual logs decode;
    // `nil` is read as "filled to full / nothing missed" (the common case) by the efficiency math.
    var filledToFull: Bool?    // false = a partial fill; its litres are summed into the next full-tank interval, not measured alone
    var missedPrevious: Bool?  // true = a fill was skipped before this one, so this interval's distance is untrustworthy
}
