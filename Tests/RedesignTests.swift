import XCTest
@testable import Koi

/// The refined-direction redesign: unit conversions (miles / MPG / gallons) and the running-cost /
/// year stats behind the Home band + the "How it's going" card.
@MainActor
final class RedesignTests: XCTestCase {

    private func units(_ d: DistanceUnit = .km, _ e: EconomyUnit = .l100, _ v: VolumeUnit = .litres) -> Units {
        let u = Units(persists: false)
        u.distance = d; u.economy = e; u.volume = v
        return u
    }

    func testDistanceMilesConversion() {
        XCTAssertEqual(units(.km).distanceValue(1000), 1000)
        XCTAssertEqual(units(.miles).distanceValue(1000), 621)        // 1000 km → ~621 mi
        XCTAssertTrue(units(.miles).distanceText(1000).hasSuffix("mi"))
    }

    func testEconomyMPGConversion() {
        XCTAssertEqual(units(.km, .l100).economyText(6.1), "6.1 L/100km")
        XCTAssertEqual(units(.km, .mpg).economyText(6.1), "39 MPG")    // 235.215 / 6.1 ≈ 38.6
    }

    func testVolumeGallonsConversion() {
        XCTAssertEqual(units(.km, .l100, .litres).volumeText(47.2), "47.2 L")
        XCTAssertEqual(units(.km, .l100, .gallons).volumeText(47.2), "12.5 gal")   // 47.2 × 0.264172
    }

    func testRunningCostAndYearStats() {
        let garage = Garage(persists: false)
        var car = Car(make: "VW", model: "Golf")
        car.initialOdometerKm = 1000
        car.odometerKm = 11000                                       // 10,000 km driven
        car.addedAt = Date().addingTimeInterval(-300 * 86_400)       // ~9.9 months owned
        garage.addOwnedCar(car)
        garage.addFuelLog(FuelLog(carID: car.id, amount: 1000, liters: 700, odometerKm: 11000, station: nil))

        let rc = garage.runningCost(for: car)
        XCTAssertNotNil(rc)
        XCTAssertEqual((rc?.perKm as NSDecimalNumber?)?.doubleValue ?? 0, 0.10, accuracy: 0.001)   // €1000 / 10,000 km
        XCTAssertGreaterThan((rc?.perMonth as NSDecimalNumber?)?.doubleValue ?? 0, 80)             // €1000 / ~9.9 mo

        XCTAssertEqual(garage.fuelLogCount(for: car), 1)
        let year = garage.distanceThisYear(for: car) ?? 0
        XCTAssertGreaterThan(year, 11000)                            // annualised ~12,000 km
        XCTAssertEqual(year, (garage.distancePerMonth(for: car) ?? 0) * 12)
    }
}
