import XCTest
@testable import Koi

/// Tier-1 regression net: deterministic checks on the pure domain logic + the wire format.
/// (Date-cycle parity — carry-over, paid-off billing — lands once Garage's `now` is injectable.)
@MainActor
final class GarageLogicTests: XCTestCase {

    // Locale-safe money parse — guards the bug where es_ES "12,50" was stored as 1250.
    func testDecimalParseLocaleSafe() {
        XCTAssertEqual(KoiFormat.decimal("12,50"), Decimal(string: "12.50"))
        XCTAssertEqual(KoiFormat.decimal("1.234,56"), Decimal(string: "1234.56"))
        XCTAssertEqual(KoiFormat.decimal("1,234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(KoiFormat.decimal("459"), Decimal(459))
    }

    // Dates round-trip through JSON (Apple reference epoch — the cross-platform wire format).
    func testDateRoundTrip() throws {
        let ref = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let data = try JSONEncoder().encode(ref)
        let back = try JSONDecoder().decode(Date.self, from: data)
        XCTAssertEqual(back.timeIntervalSinceReferenceDate, ref.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }

    // New optional fields must decode from older saves that lack them — never crash.
    func testPlanDecodesWithoutNewFields() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","kind":"finance","startedAt":0,"includesInsurance":false,"includesMaintenance":false,"includesRoadside":false,"allowsSwap":false,"carIDs":[]}"#
        let plan = try JSONDecoder().decode(Plan.self, from: Data(json.utf8))
        XCTAssertNil(plan.paidOffAt)
        XCTAssertNil(plan.mileagePools)
        XCTAssertEqual(plan.kind, .finance)
    }

    // Owned-car cost = purchase + fuel + non-note entries (date-independent sum).
    func testOwnedTotalSpent() {
        let garage = Garage(persists: false)
        var car = Car(make: "Volkswagen", model: "Golf")
        car.purchasePrice = 18_500
        garage.addOwnedCar(car)
        garage.addFuelLog(FuelLog(carID: car.id, amount: 57.20, liters: 44, odometerKm: nil, station: nil))
        garage.addLogEntry(LogEntry(carID: car.id, kind: .expense, amount: 40, note: "Car wash", odometerKm: nil))
        garage.addLogEntry(LogEntry(carID: car.id, kind: .note, amount: nil, note: "ignored", odometerKm: nil))
        XCTAssertEqual(garage.totalSpent(on: car), Decimal(string: "18597.20"))
    }
}
