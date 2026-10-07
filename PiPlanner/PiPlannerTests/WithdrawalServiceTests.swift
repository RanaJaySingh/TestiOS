import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class WithdrawalServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let accountID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Proportional calculation (BR-8 / R15)

    func testProportionalReductionsMatchSavingsWeightsAndSumToShortfall() {
        // Saved: Car 60k, Emergency 30k, Vacation 10k → 60/30/10 of ₹15,000 shortfall
        let goals = sampleGoals()
        let shortfall: Paisa = 1_500_000
        let reductions = WithdrawalService.proportionalReductions(goals: goals, shortfall: shortfall)

        XCTAssertEqual(reductions.values.reduce(0, +), shortfall)
        XCTAssertEqual(reductions[carID], 900_000)       // 60%
        XCTAssertEqual(reductions[emergencyID], 450_000) // 30%
        XCTAssertEqual(reductions[vacationID], 150_000)  // 10%
    }

    func testProportionalFractionsSumToOne() {
        let fractions = WithdrawalService.proportionalFractions(goals: sampleGoals())
        let total = fractions.values.reduce(Decimal(0), +)
        XCTAssertEqual(total, Decimal(1))
        XCTAssertEqual(fractions[carID], Decimal(string: "0.6000")!)
        XCTAssertEqual(fractions[emergencyID], Decimal(string: "0.3000")!)
        XCTAssertEqual(fractions[vacationID], Decimal(string: "0.1000")!)
    }

    func testProportionalDisplayPercentsSumTo100() {
        let percents = WithdrawalService.proportionalDisplayPercents(goals: sampleGoals())
        XCTAssertEqual(percents.values.reduce(0, +), 100)
        XCTAssertEqual(percents[carID], 60)
        XCTAssertEqual(percents[emergencyID], 30)
        XCTAssertEqual(percents[vacationID], 10)
    }

    func testProportionalFallsBackToEqualWhenAllSavedZero() {
        let goals = sampleGoals().map { goal -> Goal in
            var g = goal
            g.savedAmount = 0
            return g
        }
        let reductions = WithdrawalService.proportionalReductions(goals: goals, shortfall: 300)
        XCTAssertEqual(reductions.values.reduce(0, +), 300)
        XCTAssertEqual(Set(reductions.values), [100])
    }

    // MARK: - Validation

    func testCanSaveWhenTotalEqualsShortfallAndNoGoalBelowZero() {
        let goals = sampleGoals()
        let shortfall: Paisa = 1_500_000
        let reductions = WithdrawalService.proportionalReductions(goals: goals, shortfall: shortfall)
        XCTAssertTrue(WithdrawalService.canSave(reductions: reductions, goals: goals, shortfall: shortfall))
    }

    func testInvalidTotalDisablesSaveAndProducesRunningTotalMessage() {
        let goals = sampleGoals()
        let shortfall: Paisa = 1_500_000
        var reductions = WithdrawalService.proportionalReductions(goals: goals, shortfall: shortfall)
        reductions[carID] = (reductions[carID] ?? 0) - 100_000

        XCTAssertFalse(WithdrawalService.canSave(reductions: reductions, goals: goals, shortfall: shortfall))
        let total = WithdrawalService.totalReductions(reductions, goals: goals)
        let message = WithdrawalService.invalidTotalMessage(totalAssigned: total, shortfall: shortfall)
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("Assign the remaining") == true)
    }

    func testGoalBelowZeroIsBlocked() {
        let goals = sampleGoals()
        let shortfall: Paisa = 1_500_000
        // Vacation only has 1_000_000 saved — over-reducing it must fail.
        let reductions: [UUID: Paisa] = [
            carID: 0,
            emergencyID: 0,
            vacationID: 1_500_000
        ]
        XCTAssertFalse(WithdrawalService.canSave(reductions: reductions, goals: goals, shortfall: shortfall))
        XCTAssertEqual(
            WithdrawalService.firstGoalBelowZero(reductions: reductions, goals: goals)?.id,
            vacationID
        )
        XCTAssertThrowsError(
            try WithdrawalService.makeAllocations(
                goals: goals,
                shortfall: shortfall,
                reductions: reductions
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validationError")
            }
            XCTAssertEqual(validation.code, .goalBelowZero)
        }
    }

    func testClampedReductionNeverExceedsSaved() {
        let vacation = sampleGoals()[2]
        XCTAssertEqual(
            WithdrawalService.clampedReduction(amount: 5_000_000, for: vacation),
            vacation.savedAmount
        )
        XCTAssertEqual(WithdrawalService.clampedReduction(amount: -10, for: vacation), 0)
    }

    // MARK: - Apply + History

    func testApplyWithdrawalDecrementsSavedUpdatesBalanceAndWritesHistory() throws {
        let state = sampleState(balance: 10_000_000)
        let shortfall: Paisa = 1_500_000
        let previous: Paisa = 10_000_000
        let newBalance: Paisa = 8_500_000
        let reductions = WithdrawalService.proportionalReductions(
            goals: state.goals,
            shortfall: shortfall
        )
        let entryID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let standingBefore = state.standingSplits

        let next = try WithdrawalService.applyWithdrawal(
            to: state,
            shortfall: shortfall,
            previousBalance: previous,
            newBalance: newBalance,
            reductions: reductions,
            entryID: entryID,
            now: createdAt
        )

        XCTAssertEqual(AccountsService.dedicatedAccount(in: next.accounts)?.balance, newBalance)

        let car = try XCTUnwrap(next.goals.first { $0.id == carID })
        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        let vacation = try XCTUnwrap(next.goals.first { $0.id == vacationID })
        XCTAssertEqual(car.savedAmount, 6_000_000 - 900_000)
        XCTAssertEqual(emergency.savedAmount, 3_000_000 - 450_000)
        XCTAssertEqual(vacation.savedAmount, 1_000_000 - 150_000)
        XCTAssertEqual(next.goals.map(\.savedAmount).reduce(0, +), newBalance)

        let entry = try XCTUnwrap(next.history.last)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .withdrawal)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.withdrawalAmount, shortfall)
        XCTAssertEqual(entry.previousBalance, previous)
        XCTAssertEqual(entry.newBalance, newBalance)
        XCTAssertEqual(entry.allocations.map(\.amount).reduce(0, +), shortfall)
        XCTAssertEqual(WithdrawalService.historyTitle, "Withdrawal")

        // Standing split unchanged.
        XCTAssertEqual(next.standingSplits, standingBefore)
    }

    func testApplyWithdrawalRejectsMismatchedNewBalance() {
        let state = sampleState(balance: 10_000_000)
        let reductions = WithdrawalService.proportionalReductions(
            goals: state.goals,
            shortfall: 1_500_000
        )
        XCTAssertThrowsError(
            try WithdrawalService.applyWithdrawal(
                to: state,
                shortfall: 1_500_000,
                previousBalance: 10_000_000,
                newBalance: 9_000_000,
                reductions: reductions
            )
        )
    }

    // MARK: - Fixtures

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 10_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.50")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 5_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 3_000_000,
                shareOfNewCredits: Decimal(string: "0.30")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: vacationID,
                name: "Vacation",
                targetAmount: 2_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 1_000_000,
                shareOfNewCredits: Decimal(string: "0.20")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }

    private func sampleState(balance: Paisa) -> PersistedAppState {
        let goals = sampleGoals()
        return PersistedAppState(
            accounts: [
                Account(
                    id: accountID,
                    bankName: "HDFC",
                    maskedNumber: "••4821",
                    balance: balance,
                    isDedicated: true,
                    isPaytmLinked: true,
                    consentAutoUpdate: true
                )
            ],
            goals: goals,
            history: [],
            standingSplits: goals.map {
                StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits)
            },
            heldGoalChanges: []
        )
    }
}
