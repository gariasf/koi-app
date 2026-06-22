import Foundation
import Combine
import CoreLocation

/// Live local fuel price — the daily-fresh hook. Fetches the selected province from the
/// minetur feed, caches it (offline-tolerant), and surfaces the cheapest station.
@MainActor
final class FuelPriceStore: ObservableObject {
    @Published private(set) var stations: [FuelStation] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published var provinceID: String { didSet { if !isLoadingCache { save() } } }
    @Published var product: FuelProduct { didSet { if !isLoadingCache { save() } } }
    private var isLoadingCache = false   // suppresses didSet→save while reading the cache file

    var provinceName: String { Province.name(for: provinceID) }

    /// Live fuel prices come from the Spanish government feed (minetur), so the fuel cards and the
    /// region picker only apply in Spain. Gated on the device region — elsewhere Koi shows no
    /// prices and hides region selection, rather than silently defaulting to Madrid.
    var available: Bool { Locale.current.region?.identifier == "ES" }

    private let service = FuelPriceService()
    private let persists: Bool

    init(persists: Bool = true) {
        self.persists = persists
        self.provinceID = "28"   // Madrid default
        self.product = .diesel
        if persists {
            if ProcessInfo.processInfo.arguments.contains("-seed") { seed() } else { load() }
        }
    }

    /// Cheapest station that sells a given product (driven by the active car's fuel type).
    func cheapest(product: FuelProduct) -> FuelStation? {
        stations
            .filter { product.price($0) != nil }
            .min { (product.price($0) ?? .infinity) < (product.price($1) ?? .infinity) }
    }

    /// The closest station (selling the product) to a coordinate, with its distance in km.
    func closest(to coord: CLLocationCoordinate2D, product: FuelProduct) -> (station: FuelStation, distanceKm: Double)? {
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let priced = stations.compactMap { s -> (FuelStation, Double)? in
            guard let lat = s.latitude, let lon = s.longitude, product.price(s) != nil else { return nil }
            return (s, here.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1000)
        }
        return priced.min(by: { $0.1 < $1.1 }).map { ($0.0, $0.1) }
    }

    var freshnessText: String {
        guard let t = lastUpdated else { return "" }
        let mins = Int(Date().timeIntervalSince(t) / 60)
        if mins < 1 { return "Updated just now" }
        if mins < 60 { return "Updated \(mins)m ago" }
        let hrs = mins / 60
        return hrs < 24 ? "Updated \(hrs)h ago" : "Updated \(hrs / 24)d ago"
    }

    func refresh(province: String? = nil) async {
        guard !isLoading else { return }
        // prices move ~daily — skip the network + parse if the cache is still fresh
        if province == nil, !stations.isEmpty, let t = lastUpdated, Date().timeIntervalSince(t) < 6 * 3600 { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await service.fetch(provinceID: province ?? provinceID)
            if !fetched.isEmpty {
                stations = fetched
                lastUpdated = Date()
                save()
            }
        } catch {
            // keep cached data — the Glance still shows the last known price offline
        }
    }

    func setProvince(_ id: String) {
        guard id != provinceID else { return }
        provinceID = id
        stations = []   // drop stale region data; refresh() repopulates
    }

    // MARK: Persistence (own file, separate from the garage)
    private struct Cache: Codable {
        var stations: [FuelStation]
        var lastUpdated: Date?
        var provinceID: String
        var product: FuelProduct
    }

    private var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("koi-fuel.json")
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let c = try? JSONDecoder().decode(Cache.self, from: data) else { return }
        isLoadingCache = true
        defer { isLoadingCache = false }
        stations = c.stations
        lastUpdated = c.lastUpdated
        provinceID = c.provinceID
        product = c.product
    }

    private func save() {
        guard persists, let url = fileURL else { return }
        let c = Cache(stations: stations, lastUpdated: lastUpdated, provinceID: provinceID, product: product)
        if let data = try? JSONEncoder().encode(c) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    // MARK: Sample (SwiftUI previews + `-seed`)
    func seed() {
        stations = [
            FuelStation(id: "s1", brand: "Repsol", address: "Av. de Burgos",
                        municipality: "Madrid", province: "Madrid",
                        latitude: nil, longitude: nil, dieselPrice: 1.429, petrolPrice: 1.519),
            FuelStation(id: "s2", brand: "Cepsa", address: "Calle de Alcalá",
                        municipality: "Madrid", province: "Madrid",
                        latitude: nil, longitude: nil, dieselPrice: 1.449, petrolPrice: 1.539),
        ]
        lastUpdated = Date().addingTimeInterval(-2 * 3600)   // "2h ago"
    }

    static var preview: FuelPriceStore {
        let s = FuelPriceStore(persists: false)
        s.seed()
        return s
    }
}
