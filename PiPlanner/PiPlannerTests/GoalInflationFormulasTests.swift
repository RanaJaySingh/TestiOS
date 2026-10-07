import XCTest
@testable import PiPlannerCore

final class GoalInflationFormulasTests: XCTestCase {
    private let calendar = Calendar.gregorianUTC

    private var start: Date {
        calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
    }

    private func end(monthsAfterStart months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: start)!
    }

    func testDefaultInflationIsFivePercent() {
        XCTAssertEqual(GoalInflationFormulas.defaultInflationRate, Decimal(string: "0.05")!)
        XCTAssertEqual(GoalInflationFormulas.defaultInflationPercent, 5)
    }

    func testParseInflationPercentTextAcceptsBounds() {
        XCTAssertEqual(GoalInflationFormulas.parseInflationPercentText("0"), 0)
        XCTAssertEqual(GoalInflationFormulas.parseInflationPercentText("5"), 5)
        XCTAssertEqual(GoalInflationFormulas.parseInflationPercentText("30"), 30)
        XCTAssertNil(GoalInflationFormulas.parseInflationPercentText(""))
        XCTAssertNil(GoalInflationFormulas.parseInflationPercentText(" "))
        XCTAssertNil(GoalInflationFormulas.parseInflationPercentText("abc"))
        XCTAssertNil(GoalInflationFormulas.parseInflationPercentText("31"))
        XCTAssertNil(GoalInflationFormulas.parseInflationPercentText("-1"))
    }

    func testEffectiveInflationRateFallsBackToDefaultWhenInvalid() {
        XCTAssertEqual(
            GoalInflationFormulas.effectiveInflationRate(fromPercentText: "12"),
            Decimal(string: "0.12")!
        )
        XCTAssertEqual(
            GoalInflationFormulas.effectiveInflationRate(fromPercentText: ""),
            GoalInflationFormulas.defaultInflationRate
        )
        XCTAssertEqual(
            GoalInflationFormulas.effectiveInflationRate(fromPercentText: "99"),
            GoalInflationFormulas.defaultInflationRate
        )
    }

    func testMonthsBetweenUsesCalendarMonths() {
        XCTAssertEqual(
            GoalInflationFormulas.monthsBetween(start: start, end: end(monthsAfterStart: 12), calendar: calendar),
            12
        )
        XCTAssertEqual(
            GoalInflationFormulas.monthsBetween(start: start, end: end(monthsAfterStart: 18), calendar: calendar),
            18
        )
        XCTAssertEqual(
            GoalInflationFormulas.monthsBetween(start: start, end: start, calendar: calendar),
            0
        )
    }

    func testYearsFromMonthsIsMonthsOverTwelve() {
        XCTAssertEqual(GoalInflationFormulas.yearsFromMonths(12), 1.0, accuracy: 0.000_001)
        XCTAssertEqual(GoalInflationFormulas.yearsFromMonths(18), 1.5, accuracy: 0.000_001)
        XCTAssertEqual(GoalInflationFormulas.yearsFromMonths(6), 0.5, accuracy: 0.000_001)
    }

    func testAdjustedTargetZeroInflationEqualsTarget() {
        let target: Paisa = 10_000_000 // ₹1,00,000
        let adjusted = GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: 0,
            startDate: start,
            endDate: end(monthsAfterStart: 12),
            calendar: calendar
        )
        XCTAssertEqual(adjusted, target)
    }

    func testAdjustedTargetUsesMonthsOverTwelveExponent() {
        // target × (1.07)^(12/12) = target × 1.07
        let target: Paisa = 10_000_000
        let adjusted = GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: Decimal(string: "0.07")!,
            startDate: start,
            endDate: end(monthsAfterStart: 12),
            calendar: calendar
        )
        let expected = Paisa((Double(target) * 1.07).rounded())
        XCTAssertEqual(adjusted, expected)
    }

    func testAdjustedTargetEighteenMonthsIsOnePointFiveYears() {
        // target × (1.07)^(18/12) = target × (1.07)^1.5
        let target: Paisa = 10_000_000
        let adjusted = GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: Decimal(string: "0.07")!,
            startDate: start,
            endDate: end(monthsAfterStart: 18),
            calendar: calendar
        )
        let expected = Paisa((Double(target) * pow(1.07, 1.5)).rounded())
        XCTAssertEqual(adjusted, expected)
    }

    func testRequiredSavingsDividesGapByMonthsRemaining() {
        // (1_070_000 − 70_000) / 10 = 100_000 paisa? Wait use clear numbers:
        // adjusted 1_200_000, saved 200_000, months 10 → 100_000
        let required = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 1_200_000,
            currentSaving: 200_000,
            monthsRemaining: 10
        )
        XCTAssertEqual(required, 100_000)
    }

    func testRequiredSavingsUsesEndDateMonthsAndClampsAtOne() {
        let asOf = start
        let endDate = end(monthsAfterStart: 6)
        let required = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 600_000,
            currentSaving: 0,
            endDate: endDate,
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(required, 100_000)

        let overdue = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 50_000,
            currentSaving: 0,
            endDate: start,
            asOf: end(monthsAfterStart: 3),
            calendar: calendar
        )
        XCTAssertEqual(overdue, 50_000, "monthsRemaining floors at 1")
    }

    func testRequiredSavingsNeverNegativeWhenOverSaved() {
        let required = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 100_000,
            currentSaving: 250_000,
            monthsRemaining: 5
        )
        XCTAssertEqual(required, 0)
    }

    func testMonthlyNeedAliasMatchesRequiredSavings() {
        let endDate = end(monthsAfterStart: 12)
        let viaAlias = GoalInflationFormulas.monthlyNeedPaisa(
            adjustedTarget: 1_200_000,
            savedAmount: 0,
            endDate: endDate,
            asOf: start,
            calendar: calendar
        )
        let viaRequired = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 1_200_000,
            currentSaving: 0,
            endDate: endDate,
            asOf: start,
            calendar: calendar
        )
        XCTAssertEqual(viaAlias, viaRequired)
        XCTAssertEqual(viaAlias, 100_000)
    }

    func testGoalComputedPropertiesDelegateToFormulas() {
        let goal = Goal(
            id: UUID(),
            name: "Car",
            targetAmount: 10_000_000,
            startDate: start,
            endDate: end(monthsAfterStart: 12),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 1_000_000,
            shareOfNewCredits: Decimal(string: "0.5")!,
            createdAt: start,
            updatedAt: start
        )
        let expectedAdjusted = GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: goal.targetAmount,
            inflationRate: goal.inflationRate,
            startDate: goal.startDate,
            endDate: goal.endDate,
            calendar: calendar
        )
        XCTAssertEqual(goal.adjustedTarget, expectedAdjusted)
        XCTAssertEqual(
            goal.monthlyNeed,
            GoalInflationFormulas.requiredSavingsPaisa(
                adjustedTarget: goal.adjustedTarget,
                currentSaving: goal.savedAmount,
                endDate: goal.endDate
            )
        )
    }

    func testValidationServiceDelegatesToFormulas() {
        let endDate = end(monthsAfterStart: 12)
        let viaValidation = GoalValidationService.adjustedTargetPaisa(
            targetPaisa: 10_000_000,
            inflationRate: Decimal(string: "0.07")!,
            startDate: start,
            endDate: endDate
        )
        let viaFormulas = GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: 10_000_000,
            inflationRate: Decimal(string: "0.07")!,
            startDate: start,
            endDate: endDate
        )
        XCTAssertEqual(viaValidation, viaFormulas)

        let needValidation = GoalValidationService.requiredSavingsPaisa(
            adjustedTarget: 1_200_000,
            currentSaving: 200_000,
            endDate: endDate,
            asOf: start
        )
        let needFormulas = GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: 1_200_000,
            currentSaving: 200_000,
            endDate: endDate,
            asOf: start
        )
        XCTAssertEqual(needValidation, needFormulas)
    }
}
