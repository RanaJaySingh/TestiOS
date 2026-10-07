import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class StubLedgerServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testLockOpeningBalanceWritesHistoryAndStandingSplits() throws {
        let goals = sampleGoals()
        let state = PersistedAppState(accounts: [], goals: goals, history: [], standingSplits: [])
        let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

        let (next, entry) = try StubLedgerService.lockOpeningBalance(
            to: state,
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            entryID: entryID,
            createdAt: createdAt,
            now: createdAt
        )

        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .openingBalance)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.isTyped, true)
        XCTAssertTrue(UpdateBalanceRoutingService.assertOpeningBalanceShape(entry))
        XCTAssertEqual(next.history.count, 1)
        XCTAssertEqual(next.standingSplits.count, 2)
        XCTAssertEqual(next.goals.map(\.savedAmount).reduce(0, +), 10_000_000)
        XCTAssertEqual(
            Set(next.standingSplits.map(\.percentage)),
            Set([Decimal(string: "0.60")!, Decimal(string: "0.40")!])
        )
    }

    func testLockSingleGoalOpeningAssignsHundredPercent() throws {
        let goal = sampleGoals()[0]
        let state = PersistedAppState(accounts: [], goals: [goal], history: [], standingSplits: [])

        let (next, entry) = try StubLedgerService.lockSingleGoalOpening(
            to: state,
            goals: [goal],
            openingBalance: 5_000_000,
            isTyped: false,
            createdAt: createdAt,
            now: createdAt
        )

        XCTAssertEqual(entry.allocations.count, 1)
        XCTAssertEqual(entry.allocations[0].percentage, Decimal(1))
        XCTAssertEqual(entry.allocations[0].amount, 5_000_000)
        XCTAssertEqual(entry.isTyped, false)
        XCTAssertTrue(UpdateBalanceRoutingService.assertOpeningBalanceShape(entry))
        XCTAssertEqual(next.standingSplits, [StandingSplit(goalId: carID, percentage: Decimal(1))])
        XCTAssertEqual(next.goals[0].shareOfNewCredits, Decimal(1))
        XCTAssertEqual(next.goals[0].savedAmount, 5_000_000)
    }

    func testLockSingleGoalOpeningRejectsMultiGoal() {
        XCTAssertThrowsError(
            try StubLedgerService.lockSingleGoalOpening(
                to: PersistedAppState(accounts: [], goals: sampleGoals(), history: [], standingSplits: []),
                goals: sampleGoals(),
                openingBalance: 1
            )
        )
    }

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 0,
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
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}
