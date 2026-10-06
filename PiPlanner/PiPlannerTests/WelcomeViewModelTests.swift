import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
#endif

#if canImport(PiPlanner)
@MainActor
final class WelcomeViewModelTests: XCTestCase {
    func testExposesThreeHowItWorksStepsMatchingDesign() {
        let viewModel = WelcomeViewModel()
        XCTAssertEqual(viewModel.steps.count, 3)
        XCTAssertEqual(viewModel.steps[0].title, "Pick a savings account")
        XCTAssertEqual(viewModel.steps[0].detail, "Only its balance is read.")
        XCTAssertEqual(viewModel.steps[1].title, "Set your goals")
        XCTAssertEqual(viewModel.steps[1].detail, "A target, an end date and a share of each credit.")
        XCTAssertEqual(viewModel.steps[2].title, "Split every new credit")
        XCTAssertEqual(viewModel.steps[2].detail, "Saved amounts lock, so they stay put.")
        XCTAssertEqual(viewModel.ctaTitle, "Set up savings")
    }

    func testSetUpSavingsSignalsNavigationToAccounts() {
        let viewModel = WelcomeViewModel()
        XCTAssertFalse(viewModel.shouldNavigateToAccounts)
        viewModel.setUpSavings()
        XCTAssertTrue(viewModel.shouldNavigateToAccounts)
    }
}
#endif
