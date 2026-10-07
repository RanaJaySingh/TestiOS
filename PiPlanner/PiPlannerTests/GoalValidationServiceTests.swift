import XCTest
@testable import PiPlannerCore

final class GoalValidationServiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private var end: Date {
        start.addingTimeInterval(86_400 * 365)
    }

    func testSaveDisabledForEmptyNameZeroTargetInvalidDates() {
        XCTAssertFalse(
            GoalValidationService.canSave(
                name: "   ",
                targetPaisa: 1_000_00,
                startDate: start,
                endDate: end
            )
        )
        XCTAssertFalse(
            GoalValidationService.canSave(
                name: "Car",
                targetPaisa: 0,
                startDate: start,
                endDate: end
            )
        )
        XCTAssertFalse(
            GoalValidationService.canSave(
                name: "Car",
                targetPaisa: 1_000_00,
                startDate: end,
                endDate: start
            )
        )
        XCTAssertTrue(
            GoalValidationService.canSave(
                name: "Car",
                targetPaisa: 1_000_00,
                startDate: start,
                endDate: end
            )
        )
    }

    func testValidationErrorCodes() {
        let errors = GoalValidationService.validationErrors(
            name: "",
            targetPaisa: 0,
            startDate: end,
            endDate: start
        )
        let codes = Set(errors.map(\.code))
        XCTAssertEqual(codes, [.emptyName, .zeroTarget, .endNotAfterStart])
    }

    func testDefaultInflationIsSevenPercent() {
        XCTAssertEqual(GoalValidationService.defaultInflationRate, Decimal(string: "0.07")!)
    }

    func testAdjustedTargetUpdatesWithInflation() {
        let target: Paisa = 10_000_000 // ₹1,00,000
        let at7 = GoalValidationService.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: Decimal(string: "0.07")!,
            startDate: start,
            endDate: end
        )
        let at0 = GoalValidationService.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: 0,
            startDate: start,
            endDate: end
        )
        XCTAssertEqual(at0, target)
        XCTAssertGreaterThan(at7, at0)
        // Exact 12-calendar-month path: target × 1.07
        let calendar = Calendar.gregorianUTC
        let exactStart = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let exactEnd = calendar.date(byAdding: .month, value: 12, to: exactStart)!
        let exact = GoalValidationService.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: Decimal(string: "0.07")!,
            startDate: exactStart,
            endDate: exactEnd
        )
        XCTAssertEqual(exact, Paisa((Double(target) * 1.07).rounded()))
    }

    func testContinueRequiresHundredPercentShares() {
        let goals = GoalValidationService.goals(from: StubGrokService.happyPathProposals, now: start)
        XCTAssertTrue(GoalValidationService.canContinueWithDefinedGoals(goals))
        XCTAssertNil(GoalValidationService.splitShortfallMessage(for: goals))

        var broken = goals
        broken[0].shareOfNewCredits = Decimal(string: "0.5")!
        XCTAssertFalse(GoalValidationService.canContinueWithDefinedGoals(broken))
        XCTAssertNotNil(GoalValidationService.splitShortfallMessage(for: broken))
        XCTAssertFalse(GoalValidationService.canContinueWithDefinedGoals([]))
    }

    func testMaxFollowUpsIsTwo() {
        XCTAssertEqual(GoalValidationService.maxFollowUps, 2)
    }

    func testGoalsFromProposalsUseDefaultInflationAndZeroSaved() {
        let goals = GoalValidationService.goals(from: StubGrokService.happyPathProposals, now: start)
        XCTAssertEqual(goals.count, 2)
        XCTAssertEqual(goals[0].inflationRate, GoalValidationService.defaultInflationRate)
        XCTAssertEqual(goals[0].savedAmount, 0)
        XCTAssertEqual(goals[0].shareOfNewCredits, Decimal(string: "0.6")!)
        XCTAssertEqual(goals[1].shareOfNewCredits, Decimal(string: "0.4")!)
    }

    func testPaisaFromRupeeDigits() {
        XCTAssertEqual(GoalValidationService.paisa(fromRupeeDigits: ""), 0)
        XCTAssertEqual(GoalValidationService.paisa(fromRupeeDigits: "100000"), 10_000_000)
        XCTAssertEqual(GoalValidationService.paisa(fromRupeeDigits: "12a3"), 1_2300)
    }
}
