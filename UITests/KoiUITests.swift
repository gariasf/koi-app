import XCTest

/// Tier-B end-to-end UI tests. Drive the real app over seeded sample data (`-seed`), so the SEAT
/// León (a finance car whose term has ended) is present to exercise the payoff flow.
final class KoiUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch(_ extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seed"] + extraArgs
        app.launch()
        return app
    }

    func testLaunchShowsSeededGarage() {
        let app = launch(["-garage"])
        XCTAssertTrue(app.staticTexts["SEAT León"].waitForExistence(timeout: 10),
                      "the seeded finance car appears in the garage")
    }

    func testFinancePayoffFlow() {
        let app = launch(["-garage"])

        let leon = app.staticTexts["SEAT León"]
        XCTAssertTrue(leon.waitForExistence(timeout: 10))
        leon.tap()

        let mark = app.buttons["Mark as paid off"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "finance car offers to be marked paid off")
        mark.tap()

        // The centered confirm alert → confirm.
        let confirm = app.alerts.buttons["Mark as paid off"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "the confirm alert is presented")
        confirm.tap()

        // It quietly becomes owned.
        let nowYours = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'now yours'")).firstMatch
        XCTAssertTrue(nowYours.waitForExistence(timeout: 5), "the car now reads as owned")
    }
}
