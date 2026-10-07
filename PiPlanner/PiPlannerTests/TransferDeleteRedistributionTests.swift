import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// PIP-106 — Transfer + Delete redistribution via `LedgerEngineCore` (Linux-testable).
final class TransferDeleteRedistributionTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let entryID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Transfer → own History entry

    func testTransferViaEngineAppendsLockedHistoryEntry() throws {
        let state = twoGoalState(savedCar: 6_000_000, savedEmergency: 4_000_000)
        let standingBefore = state.standingSplits
        let historyBefore = state.history

        let next = try LedgerEngineCore.transfer(
            to: state,
            fromGoalId: carID,
            toGoalId: emergencyID,
            amountPaisa: 500_000,
            entryID: entryID,
            now: now
        )

        XCTAssertEqual(next.goals.first(where: { $0.id == carID })?.savedAmount, 5_500_000)
        XCTAssertEqual(next.goals.first(where: { $0.id == emergencyID })?.savedAmount, 4_500_000)
        XCTAssertEqual(next.standingSplits, standingBefore)

        let entry = try XCTUnwrap(next.history.last)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .transfer)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.fromGoalId, carID)
        XCTAssertEqual(entry.toGoalId, emergencyID)
        XCTAssertEqual(entry.transferAmount, 500_000)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: historyBefore, after: next.history))
    }

    // MARK: - Delete equal split + History

    func testDeleteEqualSplitRedistributesReleasedAmount() throws {
        let state = threeGoalState()
        let remainingIDs = [emergencyID, vacationID]
        let equal = DeleteGoalService.equalReassignmentFractions(
            remaining: state.goals.filter { remainingIDs.contains($0.id) }
        )

        let next = try LedgerEngineCore.deleteRedistributing(
            to: state,
            deletingGoalID: carID,
            percentages: equal,
            entryID: entryID,
            now: now
        )

        XCTAssertFalse(next.goals.contains { $0.id == carID })
        XCTAssertEqual(next.goals.count, 2)

        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        let vacation = try XCTUnwrap(next.goals.first { $0.id == vacationID })
        // Released ₹60,000 equal → ₹30,000 each; prior emergency ₹30k / vacation ₹10k
        XCTAssertEqual(emergency.savedAmount, 6_000_000)
        XCTAssertEqual(vacation.savedAmount, 4_000_000)

        let entry = try XCTUnwrap(next.history.last)
        XCTAssertEqual(entry.type, .goalDeleted)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.deletedGoalName, "Car")
        XCTAssertEqual(entry.releasedAmount, 6_000_000)
        XCTAssertEqual(entry.allocations.map(\.amount).reduce(0, +), 6_000_000)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: next.history))
    }

    // MARK: - Last-goal rule

    func testDeleteLastGoalRejectedViaEngine() {
        let sole = goal(id: carID, name: "Car", saved: 6_000_000, share: 1)
        let state = PersistedAppState(
            accounts: [],
            goals: [sole],
            history: [],
            standingSplits: [StandingSplit(goalId: carID, percentage: 1)],
            heldGoalChanges: []
        )

        XCTAssertTrue(DeleteGoalService.requiresReplacement(deletingGoalID: carID, goals: state.goals))
        XCTAssertEqual(DeleteGoalService.initialPhase(deletingGoalID: carID, goals: state.goals), .onlyGoalGate)
        XCTAssertFalse(
            DeleteGoalService.canConfirm(deletingGoalID: carID, goals: state.goals, percentages: [:])
        )
        XCTAssertThrowsError(
            try LedgerEngineCore.deleteRedistributing(
                to: state,
                deletingGoalID: carID,
                percentages: [:]
            )
        )
    }

    func testCreateReplacementThenDeleteViaEngine() throws {
        let sole = goal(id: carID, name: "Car", saved: 6_000_000, share: 1)
        var state = PersistedAppState(
            accounts: [],
            goals: [sole],
            history: [],
            standingSplits: [StandingSplit(goalId: carID, percentage: 1)],
            heldGoalChanges: []
        )

        let replacement = goal(id: emergencyID, name: "Emergency Fund", saved: 0, share: 0)
        state = DeleteGoalService.addGoalDuringDelete(
            to: state,
            goal: replacement,
            resetStandingToEqual: true,
            now: now
        )

        let remaining = DeleteGoalService.remainingGoals(deletingGoalID: carID, from: state.goals)
        let percentages = DeleteGoalService.equalReassignmentFractions(remaining: remaining)
        XCTAssertTrue(
            DeleteGoalService.canConfirm(
                deletingGoalID: carID,
                goals: state.goals,
                percentages: percentages
            )
        )

        let next = try LedgerEngineCore.deleteRedistributing(
            to: state,
            deletingGoalID: carID,
            percentages: percentages,
            resetStandingToEqual: true,
            entryID: entryID,
            now: now
        )

        XCTAssertEqual(next.goals.map(\.id), [emergencyID])
        XCTAssertEqual(next.goals[0].savedAmount, 6_000_000)
        XCTAssertEqual(next.history.last?.type, .goalDeleted)
        XCTAssertEqual(next.standingSplits.first?.percentage, 1)
    }

    // MARK: - Fixtures

    private func twoGoalState(savedCar: Paisa, savedEmergency: Paisa) -> PersistedAppState {
        let goals = [
            goal(id: carID, name: "Car", saved: savedCar, share: Decimal(string: "0.6")!),
            goal(id: emergencyID, name: "Emergency Fund", saved: savedEmergency, share: Decimal(string: "0.4")!)
        ]
        return PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: goals.map { StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits) },
            heldGoalChanges: []
        )
    }

    private func threeGoalState() -> PersistedAppState {
        let goals = [
            goal(id: carID, name: "Car", saved: 6_000_000, share: Decimal(string: "0.5")!),
            goal(id: emergencyID, name: "Emergency Fund", saved: 3_000_000, share: Decimal(string: "0.3")!),
            goal(id: vacationID, name: "Vacation", saved: 1_000_000, share: Decimal(string: "0.2")!)
        ]
        return PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: goals.map { StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits) },
            heldGoalChanges: []
        )
    }

    private func goal(id: UUID, name: String, saved: Paisa, share: Decimal) -> Goal {
        Goal(
            id: id,
            name: name,
            targetAmount: 50_000_000,
            startDate: now,
            endDate: now.addingTimeInterval(86_400 * 365),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: saved,
            shareOfNewCredits: share,
            createdAt: now,
            updatedAt: now
        )
    }
}
