import Foundation

/// A car's powertrain / fuel — shown on the car and used to label fills.
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
}
