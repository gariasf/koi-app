import Foundation
import Combine

/// Local-first store for the whole garage. The cars you live with — owned or on a plan —
/// plus their fuel logs. Persists to JSON in Application Support.
@MainActor
final class Garage: ObservableObject {
    @Published private(set) var cars: [Car] = []
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var fuelLogs: [FuelLog] = []
    @Published private(set) var logEntries: [LogEntry] = []
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
    var isEmpty: Bool { cars.isEmpty }
    /// The active car, never an archived one — falls back to the first live resident.
    var activeCar: Car? {
        if let id = activeCarID, let c = car(id), !c.isArchived { return c }
        return residents.first
    }
    func plan(for car: Car) -> Plan? { plans.first { $0.carIDs.contains(car.id) } }

    /// One card per plan — the *current* car (lineage of prior cars lives in detail). Archived
    /// cars drop out of the shelf entirely; their plan goes quiet with them.
    var residents: [Car] {
        plans.compactMap { plan in cars.first { $0.id == plan.currentCarID && !$0.isArchived } }
    }

    /// Shelved cars — the current car of any plan that's been archived. Surfaced only in the
    /// Garage's "Archived" section, where they can be restored.
    var archivedCars: [Car] {
        plans.compactMap { plan in cars.first { $0.id == plan.currentCarID && $0.isArchived } }
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
        guard let myOdo = log.odometerKm else { return nil }
        let byOdo = fuelLogs.filter { $0.carID == log.carID && $0.odometerKm != nil }
            .sorted { ($0.odometerKm ?? 0) < ($1.odometerKm ?? 0) }
        guard let idx = byOdo.firstIndex(of: log), idx > 0, let prev = byOdo[idx - 1].odometerKm else { return nil }
        let km = myOdo - prev
        guard km > 0 else { return nil }
        return log.liters / Double(km) * 100
    }

    /// Efficiency (L/100km) for every fuel log of a car, computed in one pass (one sort)
    /// instead of re-sorting all logs per row. Keyed by log id; a log with no prior reading is absent.
    func efficiencies(for car: Car) -> [UUID: Double] {
        let logs = fuelLogs(for: car).filter { $0.odometerKm != nil }
            .sorted { ($0.odometerKm ?? 0) < ($1.odometerKm ?? 0) }
        guard logs.count > 1 else { return [:] }
        var map: [UUID: Double] = [:]
        for i in 1..<logs.count {
            guard let a = logs[i].odometerKm, let b = logs[i - 1].odometerKm else { continue }
            let km = a - b
            if km > 0 { map[logs[i].id] = logs[i].liters / Double(km) * 100 }
        }
        return map
    }

    /// Km driven in the current cap cycle (month or year, per the plan), derived live from
    /// odometer history against the car's current odometer. nil if not derivable.
    func kmThisCycle(for car: Car) -> Int? {
        guard let current = car.odometerKm else { return nil }
        let cycleStart = mileageCycle(for: car).start
        var readings: [(Date, Int)] = []
        if let initial = car.initialOdometerKm { readings.append((car.addedAt, initial)) }
        readings += (car.odometerLog ?? []).map { ($0.date, $0.km) }
        readings += fuelLogs(for: car).compactMap { l in l.odometerKm.map { (l.date, $0) } }
        readings += entries(for: car).compactMap { e in e.odometerKm.map { (e.date, $0) } }
        readings.sort { $0.0 < $1.0 }
        // baseline = last reading before the cycle started; else the first reading within it
        let baseline = readings.last(where: { $0.0 < cycleStart })?.1
            ?? readings.first(where: { $0.0 >= cycleStart })?.1
        guard let base = baseline else { return nil }
        return max(0, current - base)
    }

    /// The current cap cycle window [start, end). Monthly, anchored to the plan's *start day* —
    /// a subscription that began on the 6th resets on the 6th, not the calendar 1st (the day is
    /// clamped on short months). Cars without a dated plan fall back to the calendar month.
    func mileageCycle(for car: Car, asOf now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        guard let plan = plan(for: car), plan.kind != .owned else {
            let s = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            return (s, cal.date(byAdding: .month, value: 1, to: s) ?? now)
        }
        let n = max(1, plan.capPeriod.months)              // 1 = monthly, 12 = yearly
        let anchorDay = cal.component(.day, from: plan.startedAt)
        let today = cal.startOfDay(for: now)
        // Walk forward from the plan's start in N-month steps; the last boundary on/before today is
        // the current cycle start. Anchored to the start day (clamped on short months).
        var start = cal.startOfDay(for: plan.startedAt)
        var steps = 0
        while let next = Self.boundary(after: start, addingMonths: n, anchorDay: anchorDay, cal: cal),
              next <= today, steps < 1200 {
            start = next; steps += 1
        }
        let end = Self.boundary(after: start, addingMonths: n, anchorDay: anchorDay, cal: cal) ?? start
        return (start, end)
    }

    private static func boundary(after date: Date, addingMonths n: Int, anchorDay: Int, cal: Calendar) -> Date? {
        guard let base = cal.date(byAdding: .month, value: n, to: date) else { return nil }
        return monthlyBoundary(day: anchorDay, inMonthOf: base, cal: cal)
    }

    /// The anchor day placed in `ref`'s month (clamped to that month's length), at start of day.
    private static func monthlyBoundary(day: Int, inMonthOf ref: Date, cal: Calendar) -> Date {
        var comps = cal.dateComponents([.year, .month], from: ref)
        let base = cal.date(from: comps) ?? ref
        let daysInMonth = cal.range(of: .day, in: .month, for: base)?.count ?? 28
        comps.day = min(day, daysInMonth)
        return cal.startOfDay(for: cal.date(from: comps) ?? base)
    }

    /// Whole days until the current cap cycle resets — for the gauge footnote.
    func daysUntilMileageReset(for car: Car, asOf now: Date = Date()) -> Int {
        let cal = Calendar.current
        let end = mileageCycle(for: car, asOf: now).end
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: now), to: end).day ?? 0)
    }

    /// Days the mileage gauge stays quiet after you update the odometer (i.e. acknowledge it),
    /// so it doesn't resurface the moment you've just dealt with it.
    static let mileageQuietDays = 7

    /// Mileage-cap gauges, derived live from any plan that carries a cap, so the gauge tracks
    /// real driving (and follows a swap) instead of a frozen value. Hidden for a quiet window
    /// right after you update the odometer.
    var mileageCapReminders: [Reminder] {
        plans.compactMap { plan in
            guard plan.kind != .owned, let cap = plan.mileageCapPerMonth, cap > 0,
                  let id = plan.currentCarID, let car = car(id), !car.isArchived else { return nil }
            // Quiet window: if the odometer was just updated, don't resurface the gauge yet.
            if let last = car.odometerLog?.last?.date,
               Date().timeIntervalSince(last) < Double(Self.mileageQuietDays) * 86_400 { return nil }
            var r = Reminder(carID: car.id, kind: .mileageCap, title: "Mileage this \(plan.capPeriod.noun)",
                             detail: "\(car.displayName) · \(plan.provider ?? "plan")",
                             monthlyUsedKm: kmThisCycle(for: car) ?? 0, monthlyCapKm: cap)
            r.id = plan.id   // stable identity (sheet/list diffing) tied to the plan
            return r
        }
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
        let retiringCarID = plans[pIdx].carIDs.last   // capture BEFORE appending the new car
        cars.append(newCar)
        plans[pIdx].carIDs.append(newCar.id)
        activeCarID = newCar.id
        // Carry the plan's still-active, date-based reminders onto the new car so they aren't
        // orphaned on the retired one (mileage-cap follows the plan automatically; mileage-based
        // service targets are odometer-specific, so they retire with the old car).
        if let retiringCarID {
            for i in reminders.indices where reminders[i].carID == retiringCarID
                && isActive(reminders[i]) && reminders[i].dueDate != nil {
                reminders[i].carID = newCar.id
            }
        }
        save()
    }

    func updateCar(_ car: Car) {
        guard let i = cars.firstIndex(where: { $0.id == car.id }) else { return }
        cars[i] = car
        save()
    }

    /// Set a car's current odometer directly — the in-place correction behind the live
    /// mileage-cap gauge (which derives this-month's km from the odometer).
    func setOdometer(_ km: Int, for carID: UUID) {
        guard let i = cars.firstIndex(where: { $0.id == carID }) else { return }
        cars[i].odometerKm = km
        // Record a dated reading so the monthly-mileage gauge has history to measure against —
        // even for cars that are never fuel-logged. Collapse same-day edits into one reading.
        let now = Date()
        var log = cars[i].odometerLog ?? []
        if let last = log.indices.last, Calendar.current.isDate(log[last].date, inSameDayAs: now) {
            log[last].km = km
        } else {
            log.append(OdometerReading(date: now, km: km))
        }
        cars[i].odometerLog = log
        save()
    }

    /// Shelve a car: keep it (and all its history) on file but out of the garage and every
    /// tally, until it's restored. If it was the active car, move on to a live resident.
    func archiveCar(_ car: Car) {
        guard let i = cars.firstIndex(where: { $0.id == car.id }) else { return }
        cars[i].archivedAt = Date()
        if activeCarID == car.id { activeCarID = residents.first?.id }
        save()
    }

    /// Bring a shelved car back into the garage.
    func unarchiveCar(_ car: Car) {
        guard let i = cars.firstIndex(where: { $0.id == car.id }) else { return }
        cars[i].archivedAt = nil
        save()
    }

    /// Remove a car and everything attached to it (logs, reminders, policies, documents),
    /// drop it from its plan's lineage, and retire the plan if it has no cars left.
    func deleteCar(_ car: Car) {
        let id = car.id
        cars.removeAll { $0.id == id }
        fuelLogs.removeAll { $0.carID == id }
        logEntries.removeAll { $0.carID == id }
        reminders.removeAll { $0.carID == id }
        policies.removeAll { $0.carID == id }
        documents.removeAll { $0.carID == id }
        for i in plans.indices { plans[i].carIDs.removeAll { $0 == id } }
        plans.removeAll { $0.carIDs.isEmpty }
        if activeCarID == id { activeCarID = cars.first?.id }
        save()
    }

    /// Right-to-erasure: wipe everything from memory and delete the store file from disk.
    func eraseAll() {
        cars = []; plans = []; fuelLogs = []; logEntries = []
        reminders = []; policies = []; documents = []
        activeCarID = nil
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
    }

    /// Data portability: a machine-readable JSON snapshot written to a temp file for sharing.
    func exportJSON() -> URL? {
        let state = State(cars: cars, plans: plans, fuelLogs: fuelLogs, logEntries: logEntries,
                          reminders: reminders, policies: policies, documents: documents, activeCarID: activeCarID)
        guard let data = try? JSONEncoder().encode(state) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("koi-export.json")
        try? data.write(to: url, options: .atomic)
        return url
    }

    func setActiveCar(_ id: UUID) {
        activeCarID = id
        save()
    }

    func updatePlan(_ plan: Plan) {
        guard let i = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[i] = plan
        save()
    }

    func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        if let km = entry.odometerKm,
           let i = cars.firstIndex(where: { $0.id == entry.carID }),
           km > (cars[i].odometerKm ?? 0) {
            cars[i].odometerKm = km
        }
        save()
    }

    func entries(for car: Car) -> [LogEntry] {
        logEntries.filter { $0.carID == car.id }
    }

    /// Everything spent on a car so far. Owned → purchase price; on a plan → up-front
    /// deposit + monthly × months billed (never a purchase price). Plus fuel + expenses/service.
    func totalSpent(on car: Car) -> Decimal {
        let p = plan(for: car)
        let isOwned = (p?.kind ?? .owned) == .owned

        var sum: Decimal = isOwned ? (car.purchasePrice ?? 0) : 0
        if let p, !isOwned {
            sum += p.initialPayment ?? 0
            if let monthly = p.monthlyCost {
                sum += monthly * Decimal(monthsBilled(for: p))
            }
        }
        for f in fuelLogs(for: car) { sum += f.amount }
        for e in entries(for: car) where e.kind != .note { sum += e.amount ?? 0 }
        return sum
    }

    /// Months billed on a plan so far: elapsed whole months, clamped to the plan's end date,
    /// plus the in-progress month while the plan is still active (most plans bill month 1 at signup).
    private func monthsBilled(for plan: Plan) -> Int {
        let now = Date()
        let cappedEnd = plan.endsAt.map { min($0, now) } ?? now
        var months = Calendar.current.dateComponents([.month], from: plan.startedAt, to: cappedEnd).month ?? 0
        let stillActive = (plan.endsAt ?? .distantFuture) > now
        if stillActive { months += 1 }
        return max(0, months)
    }

    func addFuelLog(_ log: FuelLog) {
        fuelLogs.append(log)
        if let i = cars.firstIndex(where: { $0.id == log.carID }),
           let odo = log.odometerKm, odo > (cars[i].odometerKm ?? 0) {
            cars[i].odometerKm = odo
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

    /// Bring in a parsed MyCar export — append its cars (each with an owned plan) and their
    /// fuel/service/expense/note history, then save once.
    func importMyCar(_ result: MyCarImporter.Result) {
        guard !result.isEmpty else { return }
        cars.append(contentsOf: result.cars)
        plans.append(contentsOf: result.plans)
        fuelLogs.append(contentsOf: result.fuels)
        logEntries.append(contentsOf: result.entries)
        if activeCarID == nil { activeCarID = result.cars.first?.id }
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

    var activeReminders: [Reminder] {
        reminders.filter { isActive($0) && !(car($0.carID)?.isArchived ?? false) } + mileageCapReminders
    }

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
            if remaining < 0 { return "overdue" }
            let rounded = ((remaining + 25) / 50) * 50
            return rounded == 0 ? "under 50 km" : "~\(rounded.formatted()) km"
        }
        if let date = r.dueDate {
            let days = daysUntil(date)
            if days < 0 { return "overdue" }
            if days == 0 { return "today" }
            if days == 1 { return "tomorrow" }
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
    private struct State: Codable, Sendable {
        var cars: [Car]
        var plans: [Plan]
        var fuelLogs: [FuelLog]?
        var logEntries: [LogEntry]?
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
        guard let url = fileURL else { return }
        guard let data = try? Data(contentsOf: url) else { return }   // absent → legitimate first run
        let state: State
        do {
            state = try JSONDecoder().decode(State.self, from: data)
        } catch {
            // Present but undecodable (corrupt / forward-incompatible): preserve it as a backup
            // so the next save() doesn't overwrite recoverable data. Then start fresh.
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            // Was assertionFailure — but that traps in Debug, so any forward-incompatible field
            // would crash the app on launch. Degrade gracefully: keep the backup, start fresh.
            print("Garage decode failed (backed up to \(backup.lastPathComponent)): \(error)")
            return
        }
        cars = state.cars
        // Lease merged into the single "Plan" kind — normalise any legacy lease plans on load.
        plans = state.plans.map { var p = $0; if p.kind == .lease { p.kind = .subscription }; return p }
        fuelLogs = state.fuelLogs ?? []
        logEntries = state.logEntries ?? []
        reminders = state.reminders ?? []
        policies = state.policies ?? []
        documents = state.documents ?? []
        activeCarID = state.activeCarID
    }

    private static let ioQueue = DispatchQueue(label: "com.gariasf.koi.garage-io", qos: .utility)

    private func save() {
        guard persists, let url = fileURL else { return }
        // snapshot on the main actor, then encode + write off it (serial queue keeps writes ordered).
        let state = State(cars: cars, plans: plans, fuelLogs: fuelLogs,
                          logEntries: logEntries, reminders: reminders, policies: policies,
                          documents: documents, activeCarID: activeCarID)
        Self.ioQueue.async {
            guard let data = try? JSONEncoder().encode(state) else { return }
            // encrypt at rest (plates, policy numbers, prices, photos) once the device is first unlocked
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    // MARK: Sample data (SwiftUI previews + the `-seed` launch arg)
    static var preview: Garage {
        let g = Garage(persists: false)
        g.seed()
        return g
    }

    /// Load a bundled demo car photo (dev seed only). CC0 imagery shipped under Resources/Seed.
    private static func seedPhoto(_ name: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
        return try? Data(contentsOf: url)
    }

    func seed() {
        // Owned — Betsy, with two fuel logs (latest derives to 6.3 L/100km)
        var betsy = Car(make: "Volkswagen", model: "Golf")
        betsy.year = 2018; betsy.nickname = "Betsy"; betsy.plate = "4821 KPD"
        betsy.odometerKm = 142_300; betsy.accent = .slate
        betsy.fuelType = .diesel; betsy.purchasePrice = 18_500; betsy.tankCapacityL = 55
        betsy.photo = Self.seedPhoto("golf")
        addOwnedCar(betsy)
        addFuelLog(FuelLog(carID: betsy.id, date: Date().addingTimeInterval(-12 * 86_400),
                           amount: 57.20, liters: 44.0, odometerKm: 141_551, station: "Repsol"))
        addFuelLog(FuelLog(carID: betsy.id, date: Date().addingTimeInterval(-5 * 86_400),
                           amount: 61.40, liters: 47.2, odometerKm: 142_300, station: "Repsol"))

        // Subscription — Mocean, Tucson swapped to a Kona 2025 (same plan continues)
        var tucson = Car(make: "Hyundai", model: "Tucson"); tucson.accent = .sage
        tucson.addedAt = Date().addingTimeInterval(-270 * 86_400)
        var sub = Plan(kind: .subscription)
        sub.provider = "Mocean"; sub.monthlyCost = 459; sub.mileageCapPerMonth = 1_500
        sub.startedAt = Date().addingTimeInterval(-71 * 86_400)   // ~Apr 6 → cap cycle resets on the 6th
        sub.includesInsurance = true; sub.includesMaintenance = true; sub.includesRoadside = true
        sub.allowsSwap = true; sub.swapIntervalMonths = 6
        let saved = addPlanCar(tucson, plan: sub)
        var kona = Car(make: "Hyundai", model: "Kona"); kona.year = 2025; kona.accent = .sage
        kona.odometerKm = 1_900; kona.initialOdometerKm = 700; kona.addedAt = Date().addingTimeInterval(-90 * 86_400)
        kona.fuelType = .hybrid
        kona.photo = Self.seedPhoto("kona")
        swapCar(in: saved, to: kona)
        // Cap cycle resets on the 6th (sub start day). Initial odo 700 (acquisition, ~3 months ago)
        // is the baseline before this cycle began; 1,900 now − 700 = 1,200 of 1,500 km (≈80% → coming
        // up). The mid-cycle fill at 1,500 sits inside the window, so it isn't the baseline.
        addFuelLog(FuelLog(carID: kona.id, date: Date().addingTimeInterval(-3 * 86_400),
                           amount: 48.30, liters: 34.5, odometerKm: 1_500, station: "Cepsa"))

        // `-calm` suppresses the coming-up items, leaving the Glance all-clear (Direction A).
        let calm = ProcessInfo.processInfo.arguments.contains("-calm")

        // Reminders — two coming up (→ Glance Direction B), two on the horizon (neutral)
        if !calm {
            addReminder(Reminder(carID: betsy.id, kind: .inspection, title: "Inspection",
                                 detail: "\(betsy.displayName) · every 2 years",
                                 dueDate: Date().addingTimeInterval(63 * 86_400)))
            addReminder(Reminder(carID: betsy.id, kind: .service, title: "Oil & filter service",
                                 detail: betsy.displayName,
                                 dueMileageKm: (betsy.odometerKm ?? 142_300) + 1_500))
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
                             title: "Inspection certificate",
                             subtitle: "Valid to " + Date().addingTimeInterval(540 * 86_400).formatted(.dateTime.month(.abbreviated).year())))

        activeCarID = betsy.id   // Glance shows the owned car + its fuel logs
        // dev: `-active2` starts on the second resident (Tucson · hybrid) to check the fuel card switches
        if ProcessInfo.processInfo.arguments.contains("-active2"), residents.count > 1 {
            activeCarID = residents[1].id
        }
    }
}
