import XCTest

/// UI tests for Goals tab layout / navigation (PIP-45).
/// Run on macOS with Xcode — Linux hosts cannot execute XCUITest.
final class GoalsTabUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-test-goals"]
        app.launch()
    }

    func testGoalsTabShowsBalanceCardAndTabBar() {
        XCTAssertTrue(
            app.descendants(matching: .any)["main.tabBar"].waitForExistence(timeout: 10)
                || app.descendants(matching: .any)["goals.tab"].waitForExistence(timeout: 10),
            "Main tabs should load for seeded post-setup state"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["goals.balanceCard"].waitForExistence(timeout: 10)
                || app.navigationBars["Goals"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["goals.balance.total"].exists
                || app.staticTexts["₹1,00,000"].exists
        )
    }

    func testGearOpensSettings() {
        let gear = app.buttons["goals.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10) || app.buttons["Settings"].waitForExistence(timeout: 10))
        if gear.exists {
            gear.tap()
        } else {
            app.buttons["Settings"].tap()
        }
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["settings.view"].waitForExistence(timeout: 8)
        )
    }

    func testGoalCardNavigatesToDetail() {
        let car = app.staticTexts["Car"]
        XCTAssertTrue(car.waitForExistence(timeout: 10))
        car.tap()
        XCTAssertTrue(
            app.navigationBars["Car"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["goals.detail"].waitForExistence(timeout: 8)
        )
    }
}
