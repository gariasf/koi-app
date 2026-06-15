import Foundation

/// A time-boxed guest. Auto-retires to history when returned. (UI lands in a later phase.)
struct Rental: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var company: String
    var car: Car
    var pickup: Date
    var dropoff: Date
    var fuelPolicyFullToFull: Bool = true
    var excess: Decimal?
    var cdwTaken: Bool = false
    var returned: Bool = false
}
