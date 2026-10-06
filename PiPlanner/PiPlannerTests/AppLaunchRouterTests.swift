import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class AppLaunchRouterTests: XCTestCase {
    func testEmptyStateIsFirstRunOrPostResetAndRoutesToWelcome() {
        let state = PersistedAppState.empty
        XCTAssertTrue(AppLaunchRouter.isFirstRunOrPostReset(state))
        XCTAssertEqual(AppLaunchRouter.destination(for: state), .welcome)
    }

    func testPostResetClearedGoalsAndHistoryRoutesToWelcome() {
        // Reset demo clears goals + history (PRD R17); accounts may be absent too after file wipe.
        let state = PersistedAppState(
            accounts: [],
            goals: [],
            history: [],
            standingSplits: []
        )
        XCTAssertTrue(AppLaunchRouter.isFirstRunOrPostReset(state))
        XCTAssertEqual(AppLaunchRouter.destination(for: state), .welcome)
    }

    func testLockedOpeningBalanceRoutesToGoals() {
        let entry = HistoryEntry(
            id: UUID(),
            type: .openingBalance,
            createdAt: Date(),
            isLocked: true,
            previousBalance: nil,
            newBalance: 10_000_000,
            creditAmount: 10_000_000,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
        let state = PersistedAppState(
            accounts: [],
            goals: [],
            history: [entry],
            standingSplits: []
        )
        XCTAssertFalse(AppLaunchRouter.isFirstRunOrPostReset(state))
        XCTAssertTrue(AppLaunchRouter.hasCompletedSetup(state))
        XCTAssertEqual(AppLaunchRouter.destination(for: state), .goals)
    }

    func testUnlockedOpeningDoesNotCompleteSetup() {
        let entry = HistoryEntry(
            id: UUID(),
            type: .openingBalance,
            createdAt: Date(),
            isLocked: false,
            previousBalance: nil,
            newBalance: 10_000_000,
            creditAmount: 10_000_000,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
        let state = PersistedAppState(
            accounts: [],
            goals: [],
            history: [entry],
            standingSplits: []
        )
        XCTAssertEqual(AppLaunchRouter.destination(for: state), .welcome)
    }
}
