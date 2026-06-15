import Foundation
import Combine

/// Local-first store for the whole garage. Residents (owned/lease/finance/subscription,
/// via plans) + guests (rentals). Persists to a JSON file in Application Support.
@MainActor
final class Garage: ObservableObject {
    @Published private(set) var cars: [Car] = []
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var rentals: [Rental] = []
    @Published var activeCarID: UUID?

    private let persists: Bool

    init(persists: Bool = true) {
        self.persists = persists
        if persists { load() }
    }

    // MARK: Derived
    var isEmpty: Bool { cars.isEmpty && rentals.isEmpty }
    var activeCar: Car? { cars.first { $0.id == activeCarID } ?? cars.first }
    func plan(for car: Car) -> Plan? { plans.first { $0.carIDs.contains(car.id) } }

    // MARK: Mutations
    func addOwnedCar(_ car: Car) {
        cars.append(car)
        plans.append(Plan(kind: .owned, carIDs: [car.id]))
        activeCarID = car.id
        save()
    }

    // MARK: Persistence
    private struct State: Codable {
        var cars: [Car]
        var plans: [Plan]
        var rentals: [Rental]
        var activeCarID: UUID?
    }

    private var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("koi-garage.json")
    }

    private func load() {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(State.self, from: data) else { return }
        cars = state.cars
        plans = state.plans
        rentals = state.rentals
        activeCarID = state.activeCarID
    }

    private func save() {
        guard persists, let url = fileURL else { return }
        let state = State(cars: cars, plans: plans, rentals: rentals, activeCarID: activeCarID)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: Previews
    static var preview: Garage {
        let g = Garage(persists: false)
        var betsy = Car(make: "Volkswagen", model: "Golf")
        betsy.year = 2018
        betsy.nickname = "Betsy"
        betsy.accent = .slate
        g.addOwnedCar(betsy)
        return g
    }
}
