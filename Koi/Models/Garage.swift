import Foundation
import Combine

/// Local-first store for the whole garage. Residents (owned/lease/finance/subscription,
/// via plans) + guests (rentals) + fuel logs. Persists to JSON in Application Support.
@MainActor
final class Garage: ObservableObject {
    @Published private(set) var cars: [Car] = []
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var rentals: [Rental] = []
    @Published private(set) var fuelLogs: [FuelLog] = []
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

    /// Residents = cars that sit on a plan (owned/lease/finance/subscription).
    var residents: [Car] { cars }

    func fuelLogs(for car: Car) -> [FuelLog] {
        fuelLogs.filter { $0.carID == car.id }.sorted { $0.date < $1.date }
    }

    func latestFuelLog(for car: Car) -> FuelLog? {
        fuelLogs(for: car).last
    }

    /// L/100km for a log, derived from the previous fill's odometer. nil if no prior fill.
    func efficiencyL100(for log: FuelLog) -> Double? {
        let byOdo = fuelLogs.filter { $0.carID == log.carID }.sorted { $0.odometerKm < $1.odometerKm }
        guard let idx = byOdo.firstIndex(of: log), idx > 0 else { return nil }
        let km = log.odometerKm - byOdo[idx - 1].odometerKm
        guard km > 0 else { return nil }
        return log.liters / Double(km) * 100
    }

    // MARK: Mutations
    func addOwnedCar(_ car: Car) {
        cars.append(car)
        plans.append(Plan(kind: .owned, carIDs: [car.id]))
        activeCarID = car.id
        save()
    }

    /// Add a car on a plan (lease/finance/subscription). Creates the plan + sets active.
    @discardableResult
    func addPlanCar(_ car: Car, plan: Plan) -> Plan {
        var plan = plan
        cars.append(car)
        plan.carIDs = [car.id]
        plans.append(plan)
        activeCarID = car.id
        save()
        return plan
    }

    func addRental(_ rental: Rental) {
        rentals.append(rental)
        save()
    }

    func addFuelLog(_ log: FuelLog) {
        fuelLogs.append(log)
        // keep the car's odometer in step with the latest reading
        if let i = cars.firstIndex(where: { $0.id == log.carID }),
           log.odometerKm > (cars[i].odometerKm ?? 0) {
            cars[i].odometerKm = log.odometerKm
        }
        save()
    }

    // MARK: Persistence
    private struct State: Codable {
        var cars: [Car]
        var plans: [Plan]
        var rentals: [Rental]
        var fuelLogs: [FuelLog]?
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
        fuelLogs = state.fuelLogs ?? []
        activeCarID = state.activeCarID
    }

    private func save() {
        guard persists, let url = fileURL else { return }
        let state = State(cars: cars, plans: plans, rentals: rentals, fuelLogs: fuelLogs, activeCarID: activeCarID)
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
        betsy.plate = "4821 KPD"
        betsy.odometerKm = 142_300
        betsy.accent = .slate
        g.addOwnedCar(betsy)
        let id = betsy.id
        g.addFuelLog(FuelLog(carID: id, date: Date().addingTimeInterval(-12 * 86_400),
                             amount: 57.20, liters: 44.0, odometerKm: 141_551, station: "Repsol"))
        g.addFuelLog(FuelLog(carID: id, date: Date().addingTimeInterval(-5 * 86_400),
                             amount: 61.40, liters: 47.2, odometerKm: 142_300, station: "Repsol"))
        return g
    }
}
