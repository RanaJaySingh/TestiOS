import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class DeleteGoalServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Reassignment defaults / validation

    func testEqualDefaultDistributionForTwoRemainingGoals() {
        let remaining = sampleGoals().filter { $0.id != carID }
        let percents = DeleteGoalService.equalReassignmentDisplayPercents(remaining: remaining)
        XCTAssertEqual(percents[emergencyID], 50)
        XCTAssertEqual(percents[vacationID], 50)
        XCTAssertEqual(percents.values.reduce(0, +), 100)
    }

    func testReassignmentAllocationsMoveExactReleasedPaisa() throws {
        let remaining = sampleGoals().filter { $0.id != carID }
        let allocations = try DeleteGoalService.makeReassignmentAllocations(
            remainingGoals: remaining,
            releasedAmount: 6_000_000,
            percentages: [
                emergencyID: Decimal(string: "0.50")!,
                vacationID: Decimal(string: "0.50")!
            ]
        )
        XCTAssertEqual(allocations.map(\.amount).reduce(0, +), 6_000_000)
        XCTAssertEqual(allocations.first { $0.goalId == emergencyID }?.amount, 3_000_000)
        XCTAssertEqual(allocations.first { $0.goalId == vacationID }?.amount, 3_000_000)
    }

    func testReassignmentRejectsWhenNotHundredPercent() {
        let remaining = sampleGoals().filter { $0.id != carID }
        XCTAssertThrowsError(
            try DeleteGoalService.makeReassignmentAllocations(
                remainingGoals: remaining,
                releasedAmount: 6_000_000,
                percentages: [
                    emergencyID: Decimal(string: "0.40")!,
                    vacationID: Decimal(string: "0.40")!
                ]
            )
        )
    }

    // MARK: - Only-goal gate

    func testOnlyGoalGateWhenDeletingSoleGoal() {
        let sole = sampleGoals()[0]
        XCTAssertTrue(
            DeleteGoalService.requiresReplacement(deletingGoalID: sole.id, goals: [sole])
        )
        XCTAssertEqual(
            DeleteGoalService.initialPhase(deletingGoalID: sole.id, goals: [sole]),
            .onlyGoalGate
        )
        XCTAssertFalse(
            DeleteGoalService.canConfirm(
                deletingGoalID: sole.id,
                goals: [sole],
                percentages: [:]
            )
        )
    }

    // MARK: - Apply deletion: money + history + standing

    func testApplyDeletionMovesMoneyAndWritesDeletedMovedHistory() throws {
        let state = sampleState()
        let percentages: [UUID: Decimal] = [
            emergencyID: Decimal(string: "0.50")!,
            vacationID: Decimal(string: "0.50")!
        ]
        let entryID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let next = try DeleteGoalService.applyDeletion(
            to: state,
            deletingGoalID: carID,
            percentages: percentages,
            entryID: entryID,
            now: createdAt
        )

        XCTAssertFalse(next.goals.contains { $0.id == carID })
        XCTAssertEqual(next.goals.count, 2)

        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        let vacation = try XCTUnwrap(next.goals.first { $0.id == vacationID })
        // Prior saved: emergency 3_000_000 + 3_000_000 moved; vacation 1_000_000 + 3_000_000
        XCTAssertEqual(emergency.savedAmount, 6_000_000)
        XCTAssertEqual(vacation.savedAmount, 4_000_000)

        let entry = try XCTUnwrap(next.history.last)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .goalDeleted)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.deletedGoalName, "Car")
        XCTAssertEqual(entry.releasedAmount, 6_000_000)
        XCTAssertEqual(entry.allocations.map(\.amount).reduce(0, +), 6_000_000)
        XCTAssertEqual(DeleteGoalService.historyTitle, "Deleted / moved")
    }

    func testApplyDeletionRenormalizesStandingSplitAcrossRemaining() throws {
        let state = sampleState()
        // Car 50%, Emergency 30%, Vacation 20% → after delete Car: 60% / 40%
        let next = try DeleteGoalService.applyDeletion(
            to: state,
            deletingGoalID: carID,
            percentages: [
                emergencyID: Decimal(string: "0.60")!,
                vacationID: Decimal(string: "0.40")!
            ],
            now: createdAt
        )

        let standingTotal = next.standingSplits.map(\.percentage).reduce(Decimal(0), +)
        XCTAssertEqual(standingTotal, Decimal(1))
        XCTAssertEqual(next.standingSplits.count, 2)

        let emergencySplit = try XCTUnwrap(next.standingSplits.first { $0.goalId == emergencyID })
        let vacationSplit = try XCTUnwrap(next.standingSplits.first { $0.goalId == vacationID })
        XCTAssertEqual(emergencySplit.percentage, Decimal(string: "0.6000")!)
        XCTAssertEqual(vacationSplit.percentage, Decimal(string: "0.4000")!)

        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        let vacation = try XCTUnwrap(next.goals.first { $0.id == vacationID })
        XCTAssertEqual(emergency.shareOfNewCredits, emergencySplit.percentage)
        XCTAssertEqual(vacation.shareOfNewCredits, vacationSplit.percentage)
    }

    func testApplyDeletionRejectsOnlyGoalWithoutReplacement() {
        let sole = sampleGoals()[0]
        let state = PersistedAppState(
            accounts: [],
            goals: [sole],
            history: [],
            standingSplits: [StandingSplit(goalId: sole.id, percentage: 1)],
            heldGoalChanges: []
        )
        XCTAssertThrowsError(
            try DeleteGoalService.applyDeletion(
                to: state,
                deletingGoalID: sole.id,
                percentages: [:]
            )
        )
    }

    // MARK: - Mid-delete create (17d)

    func testAddGoalDuringDeleteMayResetStandingToEqual() {
        let state = sampleState()
        let replacement = Goal(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            name: "House",
            targetAmount: 5_000_000,
            startDate: createdAt,
            endDate: createdAt.addingTimeInterval(86_400 * 365),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 999,
            shareOfNewCredits: 0,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let next = DeleteGoalService.addGoalDuringDelete(
            to: state,
            goal: replacement,
            resetStandingToEqual: true,
            now: createdAt
        )
        XCTAssertEqual(next.goals.count, 4)
        XCTAssertEqual(next.goals.first { $0.id == replacement.id }?.savedAmount, 0)
        let total = next.standingSplits.map(\.percentage).reduce(Decimal(0), +)
        XCTAssertEqual(total, Decimal(1))
        // Equal across 4 goals → 25% each
        for split in next.standingSplits {
            XCTAssertEqual(split.percentage, Decimal(string: "0.25")!)
        }
    }

    func testCanConfirmAfterReplacementCreatedFromOnlyGoalGate() {
        let sole = sampleGoals()[0]
        var state = PersistedAppState(
            accounts: [],
            goals: [sole],
            history: [],
            standingSplits: [StandingSplit(goalId: sole.id, percentage: 1)],
            heldGoalChanges: []
        )
        let replacement = Goal(
            id: emergencyID,
            name: "Emergency Fund",
            targetAmount: 1_000_000,
            startDate: createdAt,
            endDate: createdAt.addingTimeInterval(86_400 * 365),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 0,
            shareOfNewCredits: Decimal(string: "0.5")!,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        state = DeleteGoalService.addGoalDuringDelete(to: state, goal: replacement)
        let percents = DeleteGoalService.equalReassignmentFractions(
            remaining: DeleteGoalService.remainingGoals(deletingGoalID: sole.id, from: state.goals)
        )
        XCTAssertTrue(
            DeleteGoalService.canConfirm(
                deletingGoalID: sole.id,
                goals: state.goals,
                percentages: percents
            )
        )
        XCTAssertEqual(
            DeleteGoalService.initialPhase(deletingGoalID: sole.id, goals: state.goals),
            .reassignDefault
        )
    }

    func testApplyDeletionClearsHeldChangesForDeletedGoal() throws {
        let held = HeldGoalChange(
            id: UUID(),
            goalId: carID,
            savedAt: createdAt,
            previousName: "Car",
            pendingName: "Car Plus",
            previousTargetAmount: 1,
            pendingTargetAmount: 2,
            previousShareOfNewCredits: Decimal(string: "0.5")!,
            pendingShareOfNewCredits: Decimal(string: "0.5")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: createdAt,
            pendingStartDate: createdAt,
            previousEndDate: createdAt.addingTimeInterval(86_400),
            pendingEndDate: createdAt.addingTimeInterval(86_400 * 2)
        )
        var state = sampleState()
        state.heldGoalChanges = [held]
        let next = try DeleteGoalService.applyDeletion(
            to: state,
            deletingGoalID: carID,
            percentages: [
                emergencyID: Decimal(string: "0.50")!,
                vacationID: Decimal(string: "0.50")!
            ]
        )
        XCTAssertTrue(next.heldGoalChanges.isEmpty)
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

    private func sampleState() -> PersistedAppState {
        let goals = sampleGoals()
        return PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: goals.map {
                StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits)
            },
            heldGoalChanges: []
        )
    }
}
