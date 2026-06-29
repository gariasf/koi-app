import XCTest
@testable import Koi

/// Regression net for the MyCar-user feedback fixes: SwiftUI redraw identity, import unit/odometer/
/// sold-car handling, the derived fuel-economy line, and the editable swap price.
@MainActor
final class FeedbackFixesTests: XCTestCase {

    // MARK: Car revision (the photo/edit-redraw fix)

    // Two cars with the same id but different revision must compare UNEQUAL, so SwiftUI's value-diff
    // redraws a subview after a photo/field edit instead of treating it as no change.
    func testRevisionBreaksEquality() {
        let id = UUID()
        var a = Car(make: "VW", model: "Golf"); a = withID(a, id); a.revision = 1; a.photo = Data([1])
        var b = a; b.revision = 2; b.photo = Data([2])
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a.hashValue, b.hashValue)
    }

    // updateCar must bump the revision so a photo-only edit propagates.
    func testUpdateCarBumpsRevision() {
        let garage = Garage(persists: false)
        var car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        let before = garage.car(car.id)?.revision ?? 0
        car.photo = Data([0xAA])
        garage.updateCar(car)
        let after = garage.car(car.id)?.revision ?? 0
        XCTAssertGreaterThan(after, before)
        XCTAssertNotEqual(garage.car(car.id), car)   // stored copy is a newer revision than the input
    }

    // MARK: Import — fuel volume unit

    // A US-gallon export (fuelUnit "1") must be normalised to litres, or every derived L/100km is wrong.
    func testImportConvertsUSGallonsToLitres() {
        let csv = [
            "# My Car CSV Export v2.0", "",
            "## Vehicles",
            "id,make,model,odometerUnit,fuelUnit,purchaseOdometer,purchaseDateTime",
            "v1,Ford,F150,1,1,1000.0,2020-01-01T00:00:00.000Z", "",
            "## Refuels",
            "vehicleId,DateTime,Odometer,Amount,Total",
            "v1,2020-02-01T00:00:00.000Z,1500.0,10.0,40.00",
        ].joined(separator: "\n")
        let r = MyCarImporter.parse(csv)
        XCTAssertEqual(r.fuels.count, 1)
        XCTAssertEqual(r.fuels.first?.liters ?? 0, 37.854, accuracy: 0.01)   // 10 US gal → ~37.85 L
    }

    // A litre export (no/blank fuelUnit) is left untouched.
    func testImportLeavesLitresUntouched() {
        let csv = [
            "## Vehicles",
            "id,make,model,odometerUnit,fuelUnit,purchaseOdometer,purchaseDateTime",
            "v1,Seat,Ibiza,1,0,1000.0,2020-01-01T00:00:00.000Z", "",
            "## Refuels",
            "vehicleId,DateTime,Odometer,Amount,Total",
            "v1,2020-02-01T00:00:00.000Z,1500.0,42.0,60.00",
        ].joined(separator: "\n")
        let r = MyCarImporter.parse(csv)
        XCTAssertEqual(r.fuels.first?.liters ?? 0, 42.0, accuracy: 0.001)
    }

    // MARK: Import — sold cars + odometer trail

    // A vehicle with a selling date imports archived, so it drops out of the garage and stops nagging.
    func testImportArchivesSoldCar() {
        let csv = [
            "## Vehicles",
            "id,make,model,odometerUnit,fuelUnit,purchaseOdometer,purchaseDateTime,sellingDateTime,sellingOdometer",
            "v1,Opel,Astra,1,0,1000.0,2019-01-01T00:00:00.000Z,2022-06-01T00:00:00.000Z,90000.0",
        ].joined(separator: "\n")
        let r = MyCarImporter.parse(csv)
        XCTAssertEqual(r.cars.count, 1)
        XCTAssertNotNil(r.cars.first?.archivedAt)          // sold → archived
        XCTAssertEqual(r.cars.first?.odometerKm, 90000)    // sale odometer is the latest reading
    }

    // Dated odometer readings from every section build the trail the gauge + economy lines read.
    func testImportBuildsOdometerTrail() {
        let csv = [
            "## Vehicles",
            "id,make,model,odometerUnit,fuelUnit,purchaseOdometer,purchaseDateTime",
            "v1,VW,Golf,1,0,1000.0,2019-01-01T00:00:00.000Z", "",
            "## Refuels",
            "vehicleId,DateTime,Odometer,Amount,Total",
            "v1,2019-02-01T00:00:00.000Z,2000.0,40.0,60.00",
            "v1,2019-03-01T00:00:00.000Z,3000.0,40.0,60.00", "",
            "## OdometerEvents",
            "vehicleId,DateTime,Odometer",
            "v1,2019-04-01T00:00:00.000Z,4000.0",
        ].joined(separator: "\n")
        let r = MyCarImporter.parse(csv)
        let log = r.cars.first?.odometerLog ?? []
        XCTAssertGreaterThanOrEqual(log.count, 4)                       // purchase + 2 fills + 1 event
        XCTAssertEqual(log.map(\.km), log.map(\.km).sorted())          // kept in date order
    }

    // MARK: Derived fuel economy

    func testRecentEconomyAverageAndTrend() {
        let garage = Garage(persists: false)
        let car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        garage.addFuelLog(FuelLog(carID: car.id, amount: 60, liters: 5, odometerKm: 1000, station: nil))
        garage.addFuelLog(FuelLog(carID: car.id, amount: 60, liters: 6, odometerKm: 1100, station: nil)) // 6 L/100km
        garage.addFuelLog(FuelLog(carID: car.id, amount: 60, liters: 7, odometerKm: 1200, station: nil)) // 7 L/100km
        let e = garage.recentEconomy(for: car)
        XCTAssertNotNil(e)
        XCTAssertEqual(e?.l100 ?? 0, 6.5, accuracy: 0.001)   // mean of 6 and 7
        XCTAssertEqual(e?.trend, .creepingUp)                // newer (7) worse than older (6)
    }

    // Never fabricate a number: fewer than two paired fills → nil.
    func testRecentEconomyNeedsTwoPairs() {
        let garage = Garage(persists: false)
        let car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        garage.addFuelLog(FuelLog(carID: car.id, amount: 60, liters: 5, odometerKm: 1000, station: nil))
        garage.addFuelLog(FuelLog(carID: car.id, amount: 60, liters: 6, odometerKm: 1100, station: nil)) // only 1 paired value
        XCTAssertNil(garage.recentEconomy(for: car))
    }

    func testDistancePerMonth() {
        let garage = Garage(persists: false)
        var car = Car(make: "VW", model: "Golf")
        car.initialOdometerKm = 1000
        car.odometerKm = 2000
        car.addedAt = Date().addingTimeInterval(-100 * 24 * 3600)   // ~100 days ago
        garage.addOwnedCar(car)
        let perMonth = garage.distancePerMonth(for: garage.car(car.id) ?? car)
        XCTAssertNotNil(perMonth)
        XCTAssertEqual(Double(perMonth ?? 0), 304, accuracy: 40)    // 1000 km over ~3.29 months
    }

    // MARK: Editable swap price

    func testSwapUpdatesMonthlyCost() {
        let garage = Garage(persists: false)
        let first = Car(make: "Hyundai", model: "Kona")
        var plan = Plan(kind: .subscription)
        plan.monthlyCost = 400
        plan.allowsSwap = true
        let saved = garage.addPlanCar(first, plan: plan)
        garage.swapCar(in: saved, to: Car(make: "Hyundai", model: "Ioniq 5"), newMonthlyCost: 450)
        let current = garage.plans.first { $0.id == saved.id }
        XCTAssertEqual(current?.monthlyCost, 450)
        XCTAssertEqual(current?.carIDs.count, 2)   // lineage kept
    }

    // MARK: Trustworthy economy — full-tank-to-full-tank method

    // A partial fill isn't measured alone; its litres are summed into the enclosing full→full interval.
    func testPartialFillSummedIntoNextFull() {
        let garage = Garage(persists: false)
        let car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        garage.addFuelLog(fuel(car, t: 0, liters: 5,  odo: 1000))                       // baseline full
        garage.addFuelLog(fuel(car, t: 1, liters: 20, odo: 1300, filledToFull: false))  // partial
        garage.addFuelLog(fuel(car, t: 2, liters: 40, odo: 1600, filledToFull: true))   // full
        let map = garage.efficiencies(for: car)
        XCTAssertEqual(map.count, 1)                                  // only the full fill closes
        XCTAssertEqual(map.values.first ?? 0, 10.0, accuracy: 0.001)  // (20+40)/(1600-1000)*100
    }

    // A fill flagged as following a missed refuel produces NO number — its distance is untrustworthy.
    func testMissedFillExcluded() {
        let garage = Garage(persists: false)
        let car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        garage.addFuelLog(fuel(car, t: 0, liters: 5, odo: 1000))
        garage.addFuelLog(fuel(car, t: 1, liters: 8, odo: 1200, missedPrevious: true))
        XCTAssertTrue(garage.efficiencies(for: car).isEmpty)
    }

    // A full fill that lacks an odometer doesn't corrupt the result — its litres roll into the next
    // odometer-anchored full interval (not understated as its own bogus reading).
    func testIntermediateFillWithoutOdometerAggregated() {
        let garage = Garage(persists: false)
        let car = Car(make: "VW", model: "Golf")
        garage.addOwnedCar(car)
        garage.addFuelLog(fuel(car, t: 0, liters: 5, odo: 1000))
        garage.addFuelLog(fuel(car, t: 1, liters: 6, odo: nil))      // full, but no odometer
        garage.addFuelLog(fuel(car, t: 2, liters: 7, odo: 1200))
        let map = garage.efficiencies(for: car)
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map.values.first ?? 0, 6.5, accuracy: 0.001)  // (6+7)/(1200-1000)*100
    }

    // helper: rebuild a Car with a fixed id (Car.id is a let-by-default var via UUID())
    private func withID(_ car: Car, _ id: UUID) -> Car { var c = car; c.id = id; return c }

    // helper: a fuel log with an explicit ordering date (avoids same-instant sort ties)
    private func fuel(_ car: Car, t: Double, liters: Double, odo: Int?,
                      filledToFull: Bool? = nil, missedPrevious: Bool? = nil) -> FuelLog {
        FuelLog(carID: car.id, date: Date(timeIntervalSinceReferenceDate: t * 86_400),
                amount: 50, liters: liters, odometerKm: odo, station: nil,
                filledToFull: filledToFull, missedPrevious: missedPrevious)
    }
}
