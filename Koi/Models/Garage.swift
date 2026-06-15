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
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var policies: [InsurancePolicy] = []
    @Published private(set) var documents: [Document] = []
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

    func updateCar(_ car: Car) {
        guard let i = cars.firstIndex(where: { $0.id == car.id }) else { return }
        cars[i] = car
        save()
    }

    func updatePlan(_ plan: Plan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[i] = plan
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

    func addReminder(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
    }

    func resolve(_ reminder: Reminder) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[i].resolved = true
        save()
    }

    func snooze(_ reminder: Reminder, days: Int = 7) {
        guard let i = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[i].snoozedUntil = Date().addingTimeInterval(Double(days) * 86_400)
        save()
    }

    // MARK: Insurance & documents (relationship-aware)
    func policy(for car: Car) -> InsurancePolicy? { policies.first { $0.carID == car.id } }
    func carDocuments(for car: Car) -> [Document] { documents.filter { $0.carID == car.id } }

    /// True when insurance is bundled into the car's plan (subscription) — no policy to add.
    func insuranceIncludedInPlan(for car: Car) -> Bool {
        guard let plan = plan(for: car) else { return false }
        return plan.kind != .owned && plan.includesInsurance
    }

    func addPolicy(_ policy: InsurancePolicy, createRenewalReminder: Bool = true) {
        policies.append(policy)
        if createRenewalReminder, let due = policy.validTo {
            let name = car(policy.carID)?.displayName ?? "Your car"
            reminders.append(Reminder(carID: policy.carID, kind: .insurance,
                                      title: "Insurance renewal",
                                      detail: "\(name) · \(policy.insurer)", dueDate: due))
        }
        save()
    }

    func addDocument(_ document: Document) {
        documents.append(document)
        save()
    }

    /// Close the renewal loop: roll the policy forward a year, remember last year's premium,
    /// resolve the active insurance reminder, and schedule next year's.
    func renew(_ policy: InsurancePolicy) {
        guard let i = policies.firstIndex(where: { $0.id == policy.id }) else { return }
        let cal = Calendar.current
        if let to = policies[i].validTo {
            policies[i].premiumLastYear = policies[i].premium
            policies[i].validFrom = to
            policies[i].validTo = cal.date(byAdding: .year, value: 1, to: to)
        }
        for r in reminders where r.kind == .insurance && r.carID == policy.carID && isActive(r) {
            resolve(r)
        }
        if let due = policies[i].validTo {
            let name = car(policy.carID)?.displayName ?? "Your car"
            reminders.append(Reminder(carID: policy.carID, kind: .insurance,
                                      title: "Insurance renewal",
                                      detail: "\(name) · \(policy.insurer)", dueDate: due))
        }
        save()
    }

    // MARK: Status engine (drives the adaptive Glance: all-clear ⇄ coming-up)
    private let comingUpDays = 21
    private let comingUpKm = 2_000

    func car(_ id: UUID) -> Car? { cars.first { $0.id == id } }

    func isActive(_ r: Reminder) -> Bool {
        if r.resolved { return false }
        if let s = r.snoozedUntil, s > Date() { return false }
        return true
    }

    var activeReminders: [Reminder] { reminders.filter { isActive($0) } }

    func urgency(_ r: Reminder) -> Urgency {
        if r.kind == .mileageCap, let used = r.monthlyUsedKm, let cap = r.monthlyCapKm, cap > 0 {
            if used > cap { return .overdue }
            return Double(used) / Double(cap) >= 0.8 ? .comingUp : .neutral
        }
        if let due = r.dueMileageKm, let odo = car(r.carID)?.odometerKm {
            let remaining = due - odo
            if remaining < 0 { return .overdue }
            return remaining <= comingUpKm ? .comingUp : .neutral
        }
        if let date = r.dueDate {
            let days = daysUntil(date)
            if days < 0 { return .overdue }
            return days <= comingUpDays ? .comingUp : .neutral
        }
        return .neutral
    }

    func countdown(_ r: Reminder) -> String {
        if r.kind == .mileageCap, let used = r.monthlyUsedKm, let cap = r.monthlyCapKm {
            return "\(used.formatted())/\(cap.formatted()) km"
        }
        if let due = r.dueMileageKm, let odo = car(r.carID)?.odometerKm {
            let remaining = due - odo
            return remaining < 0 ? "overdue" : "~\(roundedKm(remaining)) km"
        }
        if let date = r.dueDate {
            let days = daysUntil(date)
            if days < 0 { return "overdue" }
            if days == 0 { return "today" }
            if days <= comingUpDays { return "in \(days) days" }
            if days <= 90 { return "in \(days / 7) weeks" }
            return date.formatted(.dateTime.day().month(.abbreviated).year())
        }
        return ""
    }

    /// All active reminders, most urgent first (overdue → coming up → neutral, then soonest).
    var sortedReminders: [Reminder] {
        activeReminders.sorted { a, b in
            let ua = urgency(a).rank, ub = urgency(b).rank
            if ua != ub { return ua < ub }
            return soonness(a) < soonness(b)
        }
    }

    var comingUp: [Reminder] { sortedReminders.filter { urgency($0) != .neutral } }
    var isAllClear: Bool { comingUp.isEmpty }
    /// When all-clear, still show the next horizon (neutral).
    var nextHorizon: Reminder? { sortedReminders.first }

    /// The car most of the coming-up items belong to ("…mostly the Golf").
    var comingUpHeadlineCar: Car? {
        let counts = Dictionary(grouping: comingUp, by: { $0.carID }).mapValues(\.count)
        guard let topID = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return car(topID)
    }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: Date())
        let to = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    private func roundedKm(_ km: Int) -> String {
        (((km + 25) / 50) * 50).formatted()
    }

    /// A rough "how soon" score in days, so date and mileage items can be ordered together.
    private func soonness(_ r: Reminder) -> Double {
        if let date = r.dueDate { return Double(daysUntil(date)) }
        if let due = r.dueMileageKm, let odo = car(r.carID)?.odometerKm {
            return Double(due - odo) / 40.0   // assume ~40 km/day
        }
        if let used = r.monthlyUsedKm, let cap = r.monthlyCapKm, cap > 0 {
            return Double(cap - used) / 50.0
        }
        return .greatestFiniteMagnitude
    }

    // MARK: Persistence
    private struct State: Codable {
        var cars: [Car]
        var plans: [Plan]
        var rentals: [Rental]
        var fuelLogs: [FuelLog]?
        var reminders: [Reminder]?
        var policies: [InsurancePolicy]?
        var documents: [Document]?
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
        reminders = state.reminders ?? []
        policies = state.policies ?? []
        documents = state.documents ?? []
        activeCarID = state.activeCarID
    }

    private func save() {
        guard persists, let url = fileURL else { return }
        let state = State(cars: cars, plans: plans, rentals: rentals, fuelLogs: fuelLogs,
                          reminders: reminders, policies: policies, documents: documents,
                          activeCarID: activeCarID)
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
        sub.allowsSwap = true; sub.swapIntervalMonths = 6
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

        // `-calm` suppresses the coming-up items, leaving the Glance all-clear (Direction A).
        let calm = ProcessInfo.processInfo.arguments.contains("-calm")

        // Reminders — two coming up (→ Glance Direction B), two on the horizon (neutral)
        if !calm {
            addReminder(Reminder(carID: betsy.id, kind: .inspection, title: "ITV inspection",
                                 detail: "\(betsy.displayName) · biennial check",
                                 dueDate: Date().addingTimeInterval(63 * 86_400)))
            addReminder(Reminder(carID: betsy.id, kind: .service, title: "Oil & filter service",
                                 detail: betsy.displayName,
                                 dueMileageKm: (betsy.odometerKm ?? 142_300) + 1_500))
            addReminder(Reminder(carID: tucson.id, kind: .mileageCap, title: "Mileage this month",
                                 detail: "\(tucson.displayName) · Mocean",
                                 monthlyUsedKm: 1_020, monthlyCapKm: 1_500))
        }

        // Insurance — Betsy carries a Mapfre policy (auto-creates the renewal reminder, 16 days)
        addPolicy(InsurancePolicy(carID: betsy.id, insurer: "Mapfre",
                                  policyNumber: "ES-4471 8820", coverage: "Comprehensive",
                                  premium: 412, premiumLastYear: 398,
                                  validFrom: Date().addingTimeInterval(-349 * 86_400),
                                  validTo: Date().addingTimeInterval(16 * 86_400)),
                  createRenewalReminder: !calm)
        addDocument(Document(carID: betsy.id, kind: .registration,
                             title: "Registration", subtitle: "Permiso de circulación"))
        addDocument(Document(carID: betsy.id, kind: .inspection,
                             title: "ITV certificate", subtitle: "Valid to Aug 2024"))

        activeCarID = betsy.id   // Glance shows the owned car + its fuel logs
    }
}
