import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class GoalDetailStandingServiceTests: XCTestCase {
    private let emergencyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let carID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let vacationID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let now = Date(timeIntervalSince1970: 1_775_000_000)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.year = y
        c.month = m
        c.day = d
        return c.date!
    }

    private func dedicatedAccount(balance: Paisa) -> Account {
        Account(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: balance,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: true
        )
    }

    // MARK: - Standing presentation

    func testShouldPresentStandingOnlyWhenTwoOrMoreGoals() {
        XCTAssertFalse(GoalDetailStandingService.shouldPresentStandingSplit(goalCount: 0))
        XCTAssertFalse(GoalDetailStandingService.shouldPresentStandingSplit(goalCount: 1))
        XCTAssertTrue(GoalDetailStandingService.shouldPresentStandingSplit(goalCount: 2))
        XCTAssertTrue(GoalDetailStandingService.shouldPresentStandingSplit(goalCount: 3))
    }

    // MARK: - Add goal → standing skip vs present

    func testFirstGoalSkipsStandingAndLocksHundredPercent() throws {
        var state = PersistedAppState.empty
        state.accounts = [dedicatedAccount(balance: 0)]

        let result = try GoalDetailStandingService.addGoal(
            to: state,
            name: "Emergency",
            targetPaisa: 5_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: emergencyID,
            now: now
        )

        XCTAssertFalse(result.shouldPresentStandingSplit)
        XCTAssertEqual(result.state.goals.count, 1)
        XCTAssertEqual(result.state.goals[0].shareOfNewCredits, 1)
        XCTAssertEqual(result.state.standingSplits.count, 1)
        XCTAssertEqual(result.state.standingSplits[0].percentage, 1)
        XCTAssertEqual(result.createdGoalID, emergencyID)
    }

    func testSecondGoalPresentsStandingSplitAndLeavesNewShareZero() throws {
        var state = PersistedAppState.empty
        state.accounts = [dedicatedAccount(balance: 10_000_000)]
        state = try GoalDetailStandingService.addGoal(
            to: state,
            name: "Emergency",
            targetPaisa: 5_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: emergencyID,
            now: now
        ).state

        let result = try GoalDetailStandingService.addGoal(
            to: state,
            name: "Car",
            targetPaisa: 50_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2028, 1, 1),
            id: carID,
            now: now
        )

        XCTAssertTrue(result.shouldPresentStandingSplit)
        XCTAssertEqual(result.state.goals.count, 2)
        XCTAssertEqual(result.state.goals.first(where: { $0.id == carID })?.savedAmount, 0)
        XCTAssertEqual(result.state.goals.first(where: { $0.id == carID })?.shareOfNewCredits, 0)
        XCTAssertTrue(
            result.state.standingSplits.contains { $0.goalId == carID && $0.percentage == 0 }
        )
    }

    // MARK: - Held edit via engine pending path

    func testCommitHeldEditUsesEnginePendingAndLeavesHistoryIntact() throws {
        var state = PersistedAppState.empty
        state.accounts = [dedicatedAccount(balance: 10_000_000)]
        state = try GoalDetailStandingService.addGoal(
            to: state,
            name: "Emergency",
            targetPaisa: 5_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: emergencyID,
            now: now
        ).state
        state = try GoalDetailStandingService.addGoal(
            to: state,
            name: "Car",
            targetPaisa: 50_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2028, 1, 1),
            id: carID,
            now: now
        ).state

        // Apply standing so shares are coherent before edit.
        state = try LedgerEngineCore.applyStanding(
            to: state,
            percentages: [
                emergencyID: Decimal(string: "0.40")!,
                carID: Decimal(string: "0.60")!
            ],
            now: now
        )
        state.goals = state.goals.map { goal in
            var g = goal
            if g.id == carID { g.savedAmount = 6_000_000 }
            if g.id == emergencyID { g.savedAmount = 4_000_000 }
            return g
        }

        let opening = try OpeningSplitService.createLockedOpeningEntry(
            goals: state.goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            createdAt: now
        )
        state.history = [opening]
        let historyBefore = state.history

        let draft = GoalDetailStandingService.editDraft(
            fromName: "Car upgrade",
            targetRupeeDigits: "150000",
            startDate: date(2026, 1, 1),
            endDate: date(2029, 1, 1),
            inflationRate: Decimal(string: "0.07")!,
            shareOfNewCredits: Decimal(string: "0.60")!,
            lockedSavedAmount: 6_000_000
        )

        let held = try GoalDetailStandingService.commitHeldEdit(
            to: state,
            goalID: carID,
            draft: draft,
            now: now
        )

        XCTAssertEqual(held.state.history, historyBefore)
        XCTAssertEqual(held.commit.updatedGoal.name, "Car upgrade")
        XCTAssertEqual(held.commit.updatedGoal.savedAmount, 6_000_000)
        XCTAssertTrue(held.commit.heldChanges.contains { $0.goalId == carID })
        XCTAssertEqual(held.commit.toastMessage, GoalHeldChangeService.toastMessage)
        XCTAssertTrue(
            LedgerEngineCore.isAppendOnlyMutation(before: historyBefore, after: held.state.history)
        )
    }

    func testEditDraftLocksSavedAmountFromCaller() {
        let draft = GoalDetailStandingService.editDraft(
            fromName: "Trip",
            targetRupeeDigits: "10000",
            startDate: date(2026, 1, 1),
            endDate: date(2026, 12, 1),
            inflationRate: Decimal(string: "0.07")!,
            shareOfNewCredits: Decimal(string: "0.5")!,
            lockedSavedAmount: 123_456
        )
        XCTAssertEqual(draft.savedAmount, 123_456)
        XCTAssertEqual(draft.targetPaisa, 1_000_000)
        XCTAssertTrue(draft.canSave)
    }

    func testThirdGoalStillPresentsStanding() throws {
        var state = PersistedAppState.empty
        state.accounts = [dedicatedAccount(balance: 0)]
        state = try GoalDetailStandingService.addGoal(
            to: state,
            name: "A",
            targetPaisa: 1_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: emergencyID,
            now: now
        ).state
        state = try GoalDetailStandingService.addGoal(
            to: state,
            name: "B",
            targetPaisa: 2_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: carID,
            now: now
        ).state
        let third = try GoalDetailStandingService.addGoal(
            to: state,
            name: "C",
            targetPaisa: 3_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: vacationID,
            now: now
        )
        XCTAssertTrue(third.shouldPresentStandingSplit)
        XCTAssertEqual(third.state.goals.count, 3)
    }
}
