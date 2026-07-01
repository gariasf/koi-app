import Foundation
import Combine

enum DistanceUnit: String, Codable, CaseIterable, Identifiable {
    case km, miles
    var id: String { rawValue }
    var short: String { self == .km ? "km" : "mi" }
    var label: String { self == .km ? "km" : "miles" }
}

enum EconomyUnit: String, Codable, CaseIterable, Identifiable {
    case l100, mpg
    var id: String { rawValue }
    var label: String { self == .l100 ? "L/100km" : "MPG" }
}

enum VolumeUnit: String, Codable, CaseIterable, Identifiable {
    case litres, gallons
    var id: String { rawValue }
    var label: String { self == .litres ? "Litres" : "Gallons" }
}

/// Display units — distance, fuel economy, volume, currency. Default quietly from the device's
/// region, then are remembered. Centralises formatting so every number reads in the chosen unit.
@MainActor
final class Units: ObservableObject {
    @Published var distance: DistanceUnit { didSet { put("distance", distance.rawValue) } }
    @Published var economy: EconomyUnit   { didSet { put("economy", economy.rawValue) } }
    @Published var volume: VolumeUnit     { didSet { put("volume", volume.rawValue) } }
    @Published var currencyCode: String   { didSet { put("currency", currencyCode) } }

    private let defaults: UserDefaults
    private let persists: Bool

    init(persists: Bool = true, defaults: UserDefaults = .standard) {
        self.persists = persists
        self.defaults = defaults
        let metric = Locale.current.measurementSystem == .metric
        func read(_ k: String) -> String? { persists ? defaults.string(forKey: "koi.units." + k) : nil }
        distance = DistanceUnit(rawValue: read("distance") ?? "") ?? (metric ? .km : .miles)
        economy  = EconomyUnit(rawValue: read("economy") ?? "")   ?? (metric ? .l100 : .mpg)
        volume   = VolumeUnit(rawValue: read("volume") ?? "")     ?? (metric ? .litres : .gallons)
        currencyCode = read("currency") ?? (Locale.current.currency?.identifier ?? "EUR")
    }
    private func put(_ k: String, _ v: String) { if persists { defaults.set(v, forKey: "koi.units." + k) } }

    private static let milesPerKm = 0.621371
    private static let gallonsPerLitre = 0.264172   // US gallon

    // MARK: distance (input is always km)
    func distanceValue(_ km: Int) -> Int { distance == .km ? km : Int((Double(km) * Self.milesPerKm).rounded()) }
    var distanceUnit: String { distance.short }
    /// "1,616 km" / "1,004 mi"
    func distanceText(_ km: Int) -> String {
        distanceValue(km).formatted(.number.grouping(.automatic)) + " " + distance.short
    }

    // MARK: fuel economy (input is always L/100km)
    var economyUnit: String { economy == .l100 ? "L/100km" : "MPG" }
    /// Bare value in the chosen unit — for stat cells that show the unit on its own line.
    func economyValue(_ l100: Double) -> String {
        switch economy {
        case .l100: return String(format: "%.1f", l100)
        case .mpg:  return String(format: "%.0f", l100 > 0 ? 235.215 / l100 : 0)
        }
    }
    /// "6.1 L/100km" / "39 MPG"
    func economyText(_ l100: Double) -> String { "\(economyValue(l100)) \(economyUnit)" }

    // MARK: volume (input is always litres)
    /// "47.2 L" / "12.5 gal"
    func volumeText(_ litres: Double) -> String {
        switch volume {
        case .litres:  return String(format: "%.1f L", litres)
        case .gallons: return String(format: "%.1f gal", litres * Self.gallonsPerLitre)
        }
    }

    // MARK: money — default to the chosen currency
    func money(_ amount: Decimal, code: String? = nil) -> String { KoiFormat.money(amount, code: code ?? currencyCode) }

    static var preview: Units { Units(persists: false) }
}
