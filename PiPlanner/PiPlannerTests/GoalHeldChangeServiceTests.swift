import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class GoalHeldChangeServiceTests: XCTestCase {
    private let goalID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let otherGoalID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private var end: Date {
        start.addingTimeInterval(86_400 * 365)
    }

    private func makeGoal(
        name: String = "Car",
        target: Paisa = 50_000_000,
        saved: Paisa = 6_000_000,
        share: Decimal = Decimal(string: "0.6")!,
        inflation: Decimal = Decimal(string: "0.07")!
    ) -> Goal {
        Goal(
            id: goalID,
            name: name,
            targetAmount: target,
            startDate: start,
            endDate: end,
            inflationRate: inflation,
            savedAmount: saved,
            shareOfNewCredits: share,
            createdAt: start,
            updatedAt: start
        )
    }

    // MARK: - Apply edit (BR-4 / R11 / R24)

    func testApplyEditUpdatesFieldsButNeverTouchesSavedAmount() {
        let goal = makeGoal(saved: 6_000_000)
        var draft = GoalEditDraft(goal: goal)
        draft.name = "New Car"
        draft.targetRupeeDigits = "600000"
        draft.shareOfNewCredits = Decimal(string: "0.55")!
        draft.inflationRate = Decimal(string: "0.08")!
        draft.savedAmount = 99_999_999 // attacker / UI bug — must stay locked

        let now = start.addingTimeInterval(3_600)
        let updated = GoalHeldChangeService.applyEdit(to: goal, draft: draft, now: now)

        XCTAssertEqual(updated.savedAmount, 6_000_000)
        XCTAssertEqual(updated.name, "New Car")
        XCTAssertEqual(updated.targetAmount, 60_000_000)
        XCTAssertEqual(updated.shareOfNewCredits, Decimal(string: "0.55")!)
        XCTAssertEqual(updated.inflationRate, Decimal(string: "0.08")!)
        XCTAssertEqual(updated.updatedAt, now)
        XCTAssertEqual(updated.createdAt, goal.createdAt)
        XCTAssertEqual(updated.id, goal.id)
    }

    func testMakeHeldChangeWhenFieldsDiffer() {
        let goal = makeGoal()
        var draft = GoalEditDraft(goal: goal)
        draft.name = "SUV"
        let change = GoalHeldChangeService.makeHeldChange(
            from: goal,
            to: draft,
            now: start.addingTimeInterval(10)
        )
        XCTAssertNotNil(change)
        XCTAssertEqual(change?.goalId, goalID)
        XCTAssertEqual(change?.previousName, "Car")
        XCTAssertEqual(change?.pendingName, "SUV")
    }

    func testMakeHeldChangeNilWhenNothingChanged() {
        let goal = makeGoal()
        let draft = GoalEditDraft(goal: goal)
        XCTAssertNil(GoalHeldChangeService.makeHeldChange(from: goal, to: draft, now: start))
    }

    func testSavedAmountOnlyChangeDoesNotCreateHeldChange() {
        let goal = makeGoal(saved: 1_000_000)
        var draft = GoalEditDraft(goal: goal)
        draft.savedAmount = 2_000_000
        XCTAssertNil(GoalHeldChangeService.makeHeldChange(from: goal, to: draft, now: start))
    }

    // MARK: - Record / query / clear

    func testRecordReplacesExistingHeldChangeForSameGoal() {
        let first = HeldGoalChange(
            id: UUID(),
            goalId: goalID,
            savedAt: start,
            previousName: "Car",
            pendingName: "A",
            previousTargetAmount: 1,
            pendingTargetAmount: 2,
            previousShareOfNewCredits: Decimal(string: "0.6")!,
            pendingShareOfNewCredits: Decimal(string: "0.5")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )
        let second = HeldGoalChange(
            id: UUID(),
            goalId: goalID,
            savedAt: start.addingTimeInterval(60),
            previousName: "Car",
            pendingName: "B",
            previousTargetAmount: 1,
            pendingTargetAmount: 3,
            previousShareOfNewCredits: Decimal(string: "0.6")!,
            pendingShareOfNewCredits: Decimal(string: "0.4")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )
        let other = HeldGoalChange(
            id: UUID(),
            goalId: otherGoalID,
            savedAt: start,
            previousName: "Emergency Fund",
            pendingName: "EF",
            previousTargetAmount: 1,
            pendingTargetAmount: 2,
            previousShareOfNewCredits: Decimal(string: "0.4")!,
            pendingShareOfNewCredits: Decimal(string: "0.5")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )

        let recorded = GoalHeldChangeService.record(second, in: [first, other])
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded.first(where: { $0.goalId == goalID })?.pendingName, "B")
        XCTAssertTrue(GoalHeldChangeService.hasHeldChange(goalId: goalID, in: recorded))
        XCTAssertTrue(GoalHeldChangeService.hasHeldChange(goalId: otherGoalID, in: recorded))
    }

    func testClearHeldChangeForGoal() {
        let change = HeldGoalChange(
            id: UUID(),
            goalId: goalID,
            savedAt: start,
            previousName: "Car",
            pendingName: "SUV",
            previousTargetAmount: 1,
            pendingTargetAmount: 2,
            previousShareOfNewCredits: Decimal(string: "0.6")!,
            pendingShareOfNewCredits: Decimal(string: "0.5")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )
        let cleared = GoalHeldChangeService.clear(goalId: goalID, in: [change])
        XCTAssertTrue(cleared.isEmpty)
        XCTAssertFalse(GoalHeldChangeService.hasHeldChange(goalId: goalID, in: cleared))
    }

    // MARK: - History isolation (BR-3 / BR-4)

    func testRelatedHistoryFiltersByAllocationOrTransferEndpoints() {
        let relatedCredit = HistoryEntry(
            id: UUID(),
            type: .newCredit,
            createdAt: start,
            isLocked: true,
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            creditAmount: 1_000_000,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: [
                GoalAllocation(
                    goalId: goalID,
                    goalName: "Car",
                    amount: 600_000,
                    percentage: Decimal(string: "0.6")!
                )
            ]
        )
        let transferOut = HistoryEntry(
            id: UUID(),
            type: .transfer,
            createdAt: start.addingTimeInterval(10),
            isLocked: true,
            previousBalance: nil,
            newBalance: nil,
            creditAmount: nil,
            isTyped: nil,
            fromGoalId: goalID,
            toGoalId: otherGoalID,
            transferAmount: 100_000,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
        let unrelated = HistoryEntry(
            id: UUID(),
            type: .newCredit,
            createdAt: start.addingTimeInterval(20),
            isLocked: true,
            previousBalance: 11_000_000,
            newBalance: 12_000_000,
            creditAmount: 1_000_000,
            isTyped: true,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: [
                GoalAllocation(
                    goalId: otherGoalID,
                    goalName: "Emergency Fund",
                    amount: 1_000_000,
                    percentage: 1
                )
            ]
        )

        let related = GoalHeldChangeService.relatedHistory(
            goalId: goalID,
            in: [unrelated, transferOut, relatedCredit]
        )
        XCTAssertEqual(related.map(\.id), [transferOut.id, relatedCredit.id])
    }

    func testApplyingHeldEditDoesNotRewriteHistory() {
        let goal = makeGoal()
        let history = [
            HistoryEntry(
                id: UUID(),
                type: .openingBalance,
                createdAt: start,
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
                allocations: [
                    GoalAllocation(
                        goalId: goalID,
                        goalName: "Car",
                        amount: 6_000_000,
                        percentage: Decimal(string: "0.6")!
                    )
                ]
            )
        ]
        var draft = GoalEditDraft(goal: goal)
        draft.name = "Renamed"
        draft.shareOfNewCredits = Decimal(string: "0.7")!

        let result = GoalHeldChangeService.commitEdit(
            goal: goal,
            draft: draft,
            history: history,
            heldChanges: [],
            standingSplits: [StandingSplit(goalId: goalID, percentage: Decimal(string: "0.6")!)],
            now: start.addingTimeInterval(100)
        )

        XCTAssertEqual(result.history, history, "BR-4: earlier History must stay unchanged")
        XCTAssertEqual(result.updatedGoal.name, "Renamed")
        XCTAssertEqual(result.updatedGoal.savedAmount, goal.savedAmount)
        XCTAssertEqual(result.updatedStandingSplits.first?.percentage, Decimal(string: "0.7")!)
        XCTAssertTrue(GoalHeldChangeService.hasHeldChange(goalId: goalID, in: result.heldChanges))
        XCTAssertEqual(result.toastMessage, GoalHeldChangeService.toastMessage)
    }

    func testToastAndHeldInfoCopy() {
        XCTAssertEqual(
            GoalHeldChangeService.toastMessage,
            "Change saved. Applies at next credit."
        )
        XCTAssertFalse(GoalHeldChangeService.heldInfoMessage.isEmpty)
        XCTAssertTrue(
            GoalHeldChangeService.heldInfoMessage.localizedCaseInsensitiveContains("next credit")
        )
    }

    func testStatusLabelMatchesGoalsTabCopy() {
        XCTAssertEqual(GoalHeldChangeService.statusLabel(for: .onTrack), "On track")
        XCTAssertEqual(GoalHeldChangeService.statusLabel(for: .behind(shortfall: 100)), "Behind")
    }

    func testCanSaveDraftUsesValidationRules() {
        var draft = GoalEditDraft(goal: makeGoal())
        XCTAssertTrue(draft.canSave)
        draft.name = "  "
        XCTAssertFalse(draft.canSave)
        draft.name = "Car"
        draft.targetRupeeDigits = "0"
        XCTAssertFalse(draft.canSave)
    }
}
