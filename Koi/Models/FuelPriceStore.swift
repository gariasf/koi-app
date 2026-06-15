import Foundation
import Combine

/// Live local fuel price — the daily-fresh hook. Fetches the selected province from the
/// minetur feed, caches it (offline-tolerant), and surfaces the cheapest station.
@MainActor
final class FuelPriceStore: ObservableObject {
    @Published private(set) var stations: [FuelStation] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published var provinceID: String { didSet { save() } }
    @Published var product: FuelProduct { didSet { save() } }

    var provinceName: String { Province.name(for: provinceID) }

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

    /// Cheapest station that sells the selected product.
    var cheapest: FuelStation? {
        stations
            .filter { product.price($0) != nil }
            .min { (product.price($0) ?? .infinity) < (product.price($1) ?? .infinity) }
    }

    var freshnessText: String {
        guard let t = lastUpdated else { return "" }
        let mins = Int(Date().timeIntervalSince(t) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let hrs = mins / 60
        return hrs < 24 ? "\(hrs)h ago" : "\(hrs / 24)d ago"
    }

    func refresh(province: String? = nil) async {
        guard !isLoading else { return }
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
        stations = c.stations
        lastUpdated = c.lastUpdated
        provinceID = c.provinceID
        product = c.product
    }

    private func save() {
        guard persists, let url = fileURL else { return }
        let c = Cache(stations: stations, lastUpdated: lastUpdated, provinceID: provinceID, product: product)
        if let data = try? JSONEncoder().encode(c) { try? data.write(to: url, options: .atomic) }
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
