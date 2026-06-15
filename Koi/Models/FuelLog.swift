import Foundation

/// A fuel stop. Efficiency (L/100km) is *derived* from consecutive odometer readings,
/// never asked. Amount + liters + odometer is all the user enters.
struct FuelLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var carID: UUID
    var date: Date = Date()
    var amount: Decimal
    var currency: String = "EUR"
    var liters: Double
    var odometerKm: Int
    var station: String?
}
