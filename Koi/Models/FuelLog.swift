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
}
