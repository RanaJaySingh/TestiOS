import XCTest

/// UI tests for History tab list / read-only (PIP-59).
/// Run on macOS with Xcode — Linux hosts cannot execute XCUITest.
final class HistoryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-test-goals"]
        app.launch()
    }

    func testHistoryTabShowsOpeningBalanceLockedEntry() {
        let historyTab = app.tabBars.buttons["History"]
        XCTAssertTrue(
            historyTab.waitForExistence(timeout: 10)
                || app.descendants(matching: .any)["tab.history"].waitForExistence(timeout: 10)
        )
        if historyTab.exists {
            historyTab.tap()
        } else if app.descendants(matching: .any)["tab.history"].exists {
            app.descendants(matching: .any)["tab.history"].tap()
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["history.tab"].waitForExistence(timeout: 10)
                || app.navigationBars["History"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.staticTexts["Opening balance"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["history.list"].waitForExistence(timeout: 8)
        )
    }

    func testLockedEntryShowsReadOnlyOriginalAmountsCaption() {
        let historyTab = app.tabBars.buttons["History"]
        if historyTab.waitForExistence(timeout: 10) {
            historyTab.tap()
        }

        let opening = app.staticTexts["Opening balance"]
        XCTAssertTrue(opening.waitForExistence(timeout: 10))
        opening.tap()

        XCTAssertTrue(
            app.staticTexts["Original amounts never change"].waitForExistence(timeout: 8)
                || app.descendants(matching: .any)["history.detail.originalCaption"].waitForExistence(timeout: 8)
        )
    }
}
