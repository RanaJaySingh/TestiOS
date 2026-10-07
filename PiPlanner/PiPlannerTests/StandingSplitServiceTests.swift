import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class StandingSplitServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - 100% validation (BR-2 / R12)

    func testMultiGoalPercentsMustSumToExactly100ToBeValid() {
        XCTAssertFalse(
            StandingSplitService.isValidHundredPercent([
                Decimal(string: "0.60")!,
                Decimal(string: "0.30")!
            ])
        )
        XCTAssertTrue(
            StandingSplitService.isValidHundredPercent([
                Decimal(string: "0.60")!,
                Decimal(string: "0.40")!
            ])
        )
        XCTAssertFalse(StandingSplitService.isValidHundredPercent([]))
    }

    func testShortfallMessageShowsRunningTotalWhenInvalid() {
        let message = StandingSplitService.shortfallMessage(for: [
            Decimal(string: "0.60")!,
            Decimal(string: "0.20")!
        ])
        XCTAssertEqual(message, "Total 80%. Assign the remaining 20%.")
    }

    func testShortfallMessageNilWhenExactlyHundred() {
        XCTAssertNil(
            StandingSplitService.shortfallMessage(for: [
                Decimal(string: "0.55")!,
                Decimal(string: "0.45")!
            ])
        )
    }

    // MARK: - Presentation / one-goal skip

    func testShouldPresentEditorOnlyForTwoOrMoreGoals() {
        XCTAssertFalse(StandingSplitService.shouldPresentEditor(goalCount: 0))
        XCTAssertFalse(StandingSplitService.shouldPresentEditor(goalCount: 1))
        XCTAssertTrue(StandingSplitService.shouldPresentEditor(goalCount: 2))
        XCTAssertTrue(StandingSplitService.shouldPresentEditor(goalCount: 3))
    }

    func testSingleGoalAutoHundredPercent() {
        let map = StandingSplitService.singleGoalPercentages(goalID: carID)
        XCTAssertEqual(map[carID], Decimal(1))
        XCTAssertTrue(StandingSplitService.isValidHundredPercent(Array(map.values)))
    }

    // MARK: - Persistence (saved money stays put)

    func testApplyStandingSplitUpdatesSharesWithoutChangingSavedAmounts() throws {
        let goals = sampleGoals()
        var state = PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: [
                StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
            ]
        )

        let next = try StandingSplitService.applyStandingSplit(
            to: state,
            percentages: [
                carID: Decimal(string: "0.70")!,
                emergencyID: Decimal(string: "0.30")!
            ],
            now: createdAt
        )

        XCTAssertEqual(next.goals.first { $0.id == carID }?.savedAmount, 6_000_000)
        XCTAssertEqual(next.goals.first { $0.id == emergencyID }?.savedAmount, 4_000_000)
        XCTAssertEqual(next.goals.first { $0.id == carID }?.shareOfNewCredits, Decimal(string: "0.70")!)
        XCTAssertEqual(next.goals.first { $0.id == emergencyID }?.shareOfNewCredits, Decimal(string: "0.30")!)
        XCTAssertEqual(
            Set(next.standingSplits.map(\.percentage)),
            Set([Decimal(string: "0.70")!, Decimal(string: "0.30")!])
        )
        XCTAssertEqual(StandingSplitService.savedMoneyStaysPutMessage, "Saved money stays put")
        _ = state
    }

    func testApplyStandingSplitRejectsWhenNotHundred() {
        let goals = sampleGoals()
        let state = PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: []
        )
        XCTAssertThrowsError(
            try StandingSplitService.applyStandingSplit(
                to: state,
                percentages: [
                    carID: Decimal(string: "0.50")!,
                    emergencyID: Decimal(string: "0.30")!
                ]
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertEqual(validation.code, .splitNotHundred)
        }
    }

    func testApplySingleGoalSkipSetsHundredPercent() throws {
        let goal = sampleGoals()[0]
        let state = PersistedAppState(
            accounts: [],
            goals: [goal],
            history: [],
            standingSplits: []
        )
        let next = try StandingSplitService.applySingleGoalSkip(to: state, now: createdAt)
        XCTAssertEqual(next.standingSplits.count, 1)
        XCTAssertEqual(next.standingSplits[0].percentage, Decimal(1))
        XCTAssertEqual(next.goals[0].shareOfNewCredits, Decimal(1))
        XCTAssertEqual(next.goals[0].savedAmount, goal.savedAmount)
    }

    // MARK: - Next credit uses standing percentages

    func testPercentagesForNextCreditUsesSavedStandingSplit() {
        let goals = sampleGoals()
        let state = PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: [
                StandingSplit(goalId: carID, percentage: Decimal(string: "0.25")!),
                StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.75")!)
            ]
        )
        let map = StandingSplitService.percentagesForNextCredit(from: state)
        XCTAssertEqual(map[carID], Decimal(string: "0.25")!)
        XCTAssertEqual(map[emergencyID], Decimal(string: "0.75")!)
        XCTAssertTrue(StandingSplitService.isValidHundredPercent(Array(map.values)))
    }

    func testPercentagesForNextCreditSingleGoalIsHundred() {
        let goal = sampleGoals()[0]
        let state = PersistedAppState(
            accounts: [],
            goals: [goal],
            history: [],
            standingSplits: []
        )
        let map = StandingSplitService.percentagesForNextCredit(from: state)
        XCTAssertEqual(map[goal.id], Decimal(1))
    }

    func testChangeAppliesNextCreditCopy() {
        XCTAssertEqual(
            StandingSplitService.changeAppliesNextCreditMessage,
            "Change saved. Applies at the next credit."
        )
    }

    // MARK: - Helpers

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}
