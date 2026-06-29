import XCTest

/// Captures the surfaces that need interaction (so plain `simctl` launch+screenshot can't reach them):
/// dialogs, log-type bodies, and the scrolled-down halves of long forms. Each saved as a kept
/// attachment; extract afterwards with `xcrun xcresulttool export attachments`.
final class ScreenshotGapsTests: XCTestCase {

    override func setUp() { continueAfterFailure = true }

    private func launch(_ args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seed"] + args
        app.launch()
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: dialogs

    func testDialogDeleteCar() {
        let app = launch(["-screen", "editcar"])
        let remove = app.buttons["Remove from garage"]
        if !remove.waitForExistence(timeout: 6) { app.swipeUp() }
        XCTAssertTrue(remove.waitForExistence(timeout: 4))
        remove.tap()
        _ = app.buttons["Cancel"].waitForExistence(timeout: 4)
        snap(app, "dialog-delete-car")
    }

    func testDialogEraseAll() {
        let app = launch(["-screen", "settings"])
        let del = app.buttons["Delete all data"]
        XCTAssertTrue(del.waitForExistence(timeout: 6))
        del.tap()
        _ = app.buttons["Cancel"].waitForExistence(timeout: 4)
        snap(app, "dialog-erase-all")
    }

    func testDialogMarkPaidOff() {
        let app = launch(["-screen", "cardetailsub"])
        let mark = app.buttons["Mark as paid off"]
        if !mark.waitForExistence(timeout: 6) { app.swipeUp() }
        if mark.waitForExistence(timeout: 4) {
            mark.tap()
            _ = app.alerts.firstMatch.waitForExistence(timeout: 4)
            snap(app, "dialog-mark-paid-off")
        }
    }

    // MARK: log-type bodies (only fuel is reachable by launch arg)

    func testLogTypeBodies() {
        let app = launch(["-screen", "log"])
        for type in ["Odometer", "Expense", "Service", "Note"] {
            let tab = app.buttons[type]
            if tab.waitForExistence(timeout: 5) {
                tab.tap()
                snap(app, "log-type-\(type.lowercased())")
            }
        }
    }

    // MARK: fuel opt-in (non-Spain region) — toggled on reveals the province picker

    func testFuelOptInToggledOn() {
        let app = launch(["-forceoptin", "-screen", "settings"])
        let toggle = app.switches["Show Spanish fuel prices"]
        if toggle.waitForExistence(timeout: 6) {
            toggle.tap()
            _ = app.buttons["Madrid"].waitForExistence(timeout: 3)
            snap(app, "settings-optin-on")
        }
    }

    // MARK: scrolled-down halves of long screens

    func testScrollLongScreens() {
        for (arg, name) in [("cardetail", "cardetail-owned"), ("editcar", "editcar-owned"), ("addplan", "addplan")] {
            let app = launch(["-screen", arg])
            _ = app.otherElements.firstMatch.waitForExistence(timeout: 5)
            app.swipeUp(); app.swipeUp()
            snap(app, "scroll-\(name)-bottom")
            app.terminate()
        }
    }
}
