import Foundation

/// A fuel station from the Spanish government (minetur) open price feed.
struct FuelStation: Identifiable, Codable, Hashable {
    var id: String            // IDEESS
    var brand: String         // Rótulo (title-cased)
    var address: String
    var municipality: String
    var province: String
    var latitude: Double?
    var longitude: Double?
    var dieselPrice: Double?  // Precio Gasoleo A
    var petrolPrice: Double?  // Precio Gasolina 95 E5
}

enum FuelProduct: String, Codable, CaseIterable, Identifiable {
    case diesel, petrol
    var id: String { rawValue }
    var label: String { self == .diesel ? "Diesel" : "Petrol" }
    var nearbyEyebrow: String { self == .diesel ? "Diesel nearby" : "Petrol nearby" }
    func price(_ s: FuelStation) -> Double? { self == .diesel ? s.dieselPrice : s.petrolPrice }
}
