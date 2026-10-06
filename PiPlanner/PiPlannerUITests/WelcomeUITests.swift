import XCTest

/// UI tests for Welcome display + navigation to Accounts (PIP-35 / PRD R1).
/// Run on macOS with Xcode — Linux hosts cannot execute XCUITest.
final class WelcomeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Force first-run / post-reset so Welcome is the root.
        app.launchArguments += ["-reset-demo"]
        app.launch()
    }

    func testWelcomeShowsThreeHowItWorksSteps() {
        XCTAssertTrue(
            app.descendants(matching: .any)["welcome.brand"].waitForExistence(timeout: 8),
            "Welcome brand should appear on first-run / post-reset"
        )
        XCTAssertTrue(app.descendants(matching: .any)["welcome.howItWorks"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["welcome.step.1"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["welcome.step.2"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["welcome.step.3"].exists)

        let step1 = app.descendants(matching: .any)["welcome.step.1"]
        XCTAssertTrue(step1.label.contains("Pick a savings account"))
        XCTAssertTrue(
            app.descendants(matching: .any)["welcome.step.2"].label.contains("Set your goals")
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["welcome.step.3"].label.contains("Split every new credit")
        )
    }

    func testSetUpSavingsNavigatesToAccounts() {
        let cta = app.buttons["welcome.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        cta.tap()

        XCTAssertTrue(
            app.navigationBars["Accounts"].waitForExistence(timeout: 8),
            "CTA should navigate to existing Accounts screen"
        )
        XCTAssertTrue(app.staticTexts["Choose dedicated savings"].exists)
    }
}
