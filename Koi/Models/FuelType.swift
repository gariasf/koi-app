import Foundation

/// A car's powertrain / fuel. Drives the Glance "nearby price" card (which liquid fuel,
/// or none for electric) and is shown on the car.
enum FuelType: String, Codable, CaseIterable, Identifiable {
    case petrol, diesel, electric, hybrid, mildHybrid, pluginHybrid, lpg, cng, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .petrol:        return "Petrol"
        case .diesel:        return "Diesel"
        case .electric:      return "Electric"
        case .hybrid:        return "Hybrid"
        case .mildHybrid:    return "Mild hybrid"
        case .pluginHybrid:  return "Plug-in hybrid"
        case .lpg:           return "LPG"
        case .cng:           return "CNG"
        case .other:         return "Other"
        }
    }

    /// The liquid-fuel price that applies for "nearby" — nil means no petrol/diesel price
    /// (electric, gas, other → the card hides or adapts).
    var nearbyProduct: FuelProduct? {
        switch self {
        case .petrol, .hybrid, .mildHybrid, .pluginHybrid: return .petrol
        case .diesel:                                      return .diesel
        case .electric, .lpg, .cng, .other:                return nil
        }
    }
}
