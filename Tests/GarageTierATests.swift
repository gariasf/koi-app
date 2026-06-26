import XCTest
@testable import Koi

/// Tier-A regression net (iOS). Covers the finance→owned payoff lifecycle, swap lineage, cap-cycle
/// anchoring, countdown/urgency and the pool guards. Date-driven checks ride a fixture built relative
/// to the same `Date()` the logic reads, so they stay deterministic; the exact carry-over magnitude
/// (which needs an injected clock) is covered on the Android port.
@MainActor
final class GarageTierATests: XCTestCase {

    private let cal = Calendar.current
    private func ago(_ days: Double) -> Date { Date().addingTimeInterval(-days * 86_400) }
    private func ahead(_ days: Double) -> Date { Date().addingTimeInterval(days * 86_400) }
    private func isoDate(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current; f.calendar = .current
        return f.date(from: s)!
    }

    private func financeCar(into g: Garage, started: Date, ends: Date, monthly: Decimal? = nil, paidOff: Date? = nil) -> Car {
        let car = Car(make: "SEAT", model: "Leon")
        var plan = Plan(kind: .finance)
        plan.startedAt = started; plan.endsAt = ends; plan.monthlyCost = monthly; plan.paidOffAt = paidOff
        _ = g.addPlanCar(car, plan: plan)
        return car
    }

    // --- Finance → owned payoff lifecycle ---

    func testFinancePayoffLifecycle() {
        let g = Garage(persists: false)
        let car = financeCar(into: g, started: ago(1130), ends: ago(30), monthly: 245)

        XCTAssertTrue(g.financeAwaitingPayoff(car), "term ended, not yet paid")
        XCTAssertFalse(g.ownsOutright(car))

        g.markPaidOff(car)
        XCTAssertTrue(g.ownsOutright(car), "paid off → now owned")
        XCTAssertFalse(g.financeAwaitingPayoff(car))

        g.undoPaidOff(car)
        XCTAssertTrue(g.financeAwaitingPayoff(car), "undo restores the awaiting state")
        XCTAssertFalse(g.ownsOutright(car))
    }

    func testPayoffStopsBilling() {
        func cost(paidMonthsAgo: Double?) -> Decimal {
            let g = Garage(persists: false)
            let car = financeCar(into: g, started: ago(365), ends: ahead(365), monthly: 100,
                                 paidOff: paidMonthsAgo.map { ago($0 * 30) })
            return g.totalSpent(on: car)
        }
        XCTAssertLessThan(cost(paidMonthsAgo: 6), cost(paidMonthsAgo: nil), "payoff caps monthly billing")
    }

    // --- Swap lineage ---

    func testSwapKeepsPlanLineage() {
        let g = Garage(persists: false)
        let a = Car(make: "Hyundai", model: "Tucson")
        let b = Car(make: "Hyundai", model: "Kona")
        var plan = Plan(kind: .subscription); plan.allowsSwap = true
        let saved = g.addPlanCar(a, plan: plan)
        g.swapCar(in: saved, to: b)

        let p = g.plan(for: b)!
        XCTAssertEqual(p.carIDs, [a.id, b.id], "both cars in lineage order")
        XCTAssertEqual(p.carIDs.last, b.id, "the new car is current")
    }

    // --- Cap-cycle anchoring (deterministic via asOf) ---

    func testMileageCycleAnchorsToStartDay() {
        let g = Garage(persists: false)
        let car = Car(make: "Renault", model: "Clio")
        var plan = Plan(kind: .lease)
        plan.startedAt = isoDate("2026-03-15"); plan.mileageCapPerMonth = 1000; plan.mileageCapPeriod = .month
        _ = g.addPlanCar(car, plan: plan)

        let asOf = isoDate("2026-06-20")
        let cycle = g.mileageCycle(for: car, asOf: asOf)
        XCTAssertEqual(cal.component(.day, from: cycle.start), 15, "cycle anchors to the plan start day")
        XCTAssertTrue(cycle.start <= asOf && asOf < cycle.end, "asOf falls inside its cycle")
    }

    // --- Pool guards (date-independent) ---

    func testNoPoolForOwnedOrPoolingOff() {
        let g = Garage(persists: false)
        let owned = Car(make: "Mazda", model: "3"); g.addOwnedCar(owned)
        XCTAssertNil(g.mileagePool(for: owned), "owned cars have no pool")

        let car = Car(make: "Renault", model: "Clio")
        var plan = Plan(kind: .lease)
        plan.startedAt = ago(120); plan.mileageCapPerMonth = 1000; plan.mileageCapPeriod = .month; plan.mileagePools = false
        _ = g.addPlanCar(car, plan: plan)
        XCTAssertNil(g.mileagePool(for: car), "pooling off → no pool")
    }

    // --- Countdown + urgency (relative to today) ---

    private func owned(_ g: Garage) -> Car {
        let car = Car(make: "A", model: "B"); g.addOwnedCar(car); return car
    }
    private func dueReminder(_ car: Car, inDays days: Int) -> Reminder {
        var r = Reminder(carID: car.id, kind: .inspection, title: "x", detail: "y")
        r.dueDate = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))
        return r
    }

    func testCountdownDateBranches() {
        let g = Garage(persists: false); let car = owned(g)
        XCTAssertEqual(g.countdown(dueReminder(car, inDays: 0)), "today")
        XCTAssertEqual(g.countdown(dueReminder(car, inDays: 1)), "tomorrow")
        XCTAssertEqual(g.countdown(dueReminder(car, inDays: 3)), "in 3 days")
        XCTAssertEqual(g.countdown(dueReminder(car, inDays: 30)), "in 4 weeks")
        XCTAssertEqual(g.countdown(dueReminder(car, inDays: -1)), "overdue")
    }

    func testUrgencyEscalates() {
        let g = Garage(persists: false); let car = owned(g)
        XCTAssertEqual(g.urgency(dueReminder(car, inDays: -1)), .overdue)
        XCTAssertEqual(g.urgency(dueReminder(car, inDays: 5)), .comingUp)
        XCTAssertEqual(g.urgency(dueReminder(car, inDays: 120)), .neutral)

        var over = Reminder(carID: car.id, kind: .mileageCap, title: "x", detail: "y")
        over.monthlyUsedKm = 1600; over.monthlyCapKm = 1500
        XCTAssertEqual(g.urgency(over), .overdue, "over the pooled budget is overdue")
    }
}
