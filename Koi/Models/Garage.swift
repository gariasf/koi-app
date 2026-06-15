import Foundation
import Combine

/// Local-first store for the whole garage. Residents (current car of each plan) +
/// guests (rentals) + fuel logs. Persists to JSON in Application Support.
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
        if persists {
            if ProcessInfo.processInfo.arguments.contains("-seed") { seed() } else { load() }
        }
    }

    // MARK: Derived
    var isEmpty: Bool { cars.isEmpty && rentals.isEmpty }
    var activeCar: Car? { cars.first { $0.id == activeCarID } ?? cars.first }
    func plan(for car: Car) -> Plan? { plans.first { $0.carIDs.contains(car.id) } }

    /// One card per plan — the *current* car (lineage of prior cars lives in detail).
    var residents: [Car] {
        plans.compactMap { plan in cars.first { $0.id == plan.currentCarID } }
    }

    /// The ordered cars that have occupied a plan (oldest → current).
    func lineage(for plan: Plan) -> [Car] {
        plan.carIDs.compactMap { id in cars.first { $0.id == id } }
    }

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

    /// The Plan ▸ Car proof: the same plan continues, the new car joins the lineage,
    /// cost/reminders/mileage carry over, the prior car retires into history.
    func swapCar(in plan: Plan, to newCar: Car) {
        guard let pIdx = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        cars.append(newCar)
        plans[pIdx].carIDs.append(newCar.id)
        activeCarID = newCar.id
        save()
    }

    func addRental(_ rental: Rental) {
        rentals.append(rental)
        save()
    }

    func markReturned(_ rental: Rental) {
        guard let i = rentals.firstIndex(where: { $0.id == rental.id }) else { return }
        rentals[i].returned = true
        save()
    }

    func addFuelLog(_ log: FuelLog) {
        fuelLogs.append(log)
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

    // MARK: Sample data (SwiftUI previews + the `-seed` launch arg)
    static var preview: Garage {
        let g = Garage(persists: false)
        g.seed()
        return g
    }

    func seed() {
        // Owned — Betsy, with two fuel logs (latest derives to 6.3 L/100km)
        var betsy = Car(make: "Volkswagen", model: "Golf")
        betsy.year = 2018; betsy.nickname = "Betsy"; betsy.plate = "4821 KPD"
        betsy.odometerKm = 142_300; betsy.accent = .slate
        addOwnedCar(betsy)
        addFuelLog(FuelLog(carID: betsy.id, date: Date().addingTimeInterval(-12 * 86_400),
                           amount: 57.20, liters: 44.0, odometerKm: 141_551, station: "Repsol"))
        addFuelLog(FuelLog(carID: betsy.id, date: Date().addingTimeInterval(-5 * 86_400),
                           amount: 61.40, liters: 47.2, odometerKm: 142_300, station: "Repsol"))

        // Subscription — Mocean, Kona swapped to Tucson (same plan continues)
        var kona = Car(make: "Hyundai", model: "Kona"); kona.accent = .sage
        kona.addedAt = Date().addingTimeInterval(-270 * 86_400)
        var sub = Plan(kind: .subscription)
        sub.provider = "Mocean"; sub.monthlyCost = 459; sub.mileageCapPerMonth = 1_500
        sub.includesInsurance = true; sub.includesMaintenance = true; sub.includesRoadside = true
        sub.allowsSwap = true
        let saved = addPlanCar(kona, plan: sub)
        var tucson = Car(make: "Hyundai", model: "Tucson"); tucson.accent = .sage
        tucson.odometerKm = 1_020; tucson.addedAt = Date().addingTimeInterval(-90 * 86_400)
        swapCar(in: saved, to: tucson)

        // Guest — a returned rental
        var fiat = Car(make: "Fiat", model: "500"); fiat.accent = .terracotta
        addRental(Rental(company: "Europcar", car: fiat,
                         pickup: Date().addingTimeInterval(-40 * 86_400),
                         dropoff: Date().addingTimeInterval(-36 * 86_400),
                         fuelPolicyFullToFull: true, excess: 1_200, cdwTaken: true, returned: true))

        activeCarID = betsy.id   // Glance shows the owned car + its fuel logs
    }
}
