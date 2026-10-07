import Foundation

/// Delete-goal reassignment + History lock (PRD R13, Spec BR-9 / BR-2).
/// Pure / Linux-testable. Money moves as paisa (`Int64`); splits are 0.0–1.0 fractions.
enum DeleteGoalService {
    /// UI / flow phases for frames 17 / 17a–17e.
    enum Phase: String, Equatable, Sendable {
        case onlyGoalGate
        case reassignDefault
        case reassignEdit
        case confirm
    }

    /// History row copy for a locked deletion entry (AC / PRD R13).
    static let historyTitle = "Deleted / moved"

    /// Caption when the only goal would be removed (frame 17e).
    static let onlyGoalGateMessage =
        "Create another goal before deleting this one. Confirm stays disabled until a replacement exists."

    /// Caption under reassignment (frame 17).
    static let reassignCaption =
        "Move this goal’s saved money to the remaining goals. Equal split by default — you can edit once before confirm."

    // MARK: - Gate / remaining

    /// Goals that remain after deleting `goalID`.
    static func remainingGoals(deletingGoalID: UUID, from goals: [Goal]) -> [Goal] {
        goals.filter { $0.id != deletingGoalID }
    }

    /// True when deleting would leave zero goals (frame 17e).
    static func requiresReplacement(deletingGoalID: UUID, goals: [Goal]) -> Bool {
        remainingGoals(deletingGoalID: deletingGoalID, from: goals).isEmpty
    }

    /// Initial phase for the delete flow.
    static func initialPhase(deletingGoalID: UUID, goals: [Goal]) -> Phase {
        requiresReplacement(deletingGoalID: deletingGoalID, goals: goals)
            ? .onlyGoalGate
            : .reassignDefault
    }

    // MARK: - Default reassignment

    /// Equal default display percents for remaining goals.
    static func equalReassignmentDisplayPercents(remaining: [Goal]) -> [UUID: Int] {
        StandingSplitService.equalDisplayPercents(for: remaining.map(\.id))
    }

    /// Equal default fractions for remaining goals.
    static func equalReassignmentFractions(remaining: [Goal]) -> [UUID: Decimal] {
        StandingSplitService.equalFractions(for: remaining.map(\.id))
    }

    // MARK: - Allocations / History

    /// Builds per-goal allocations that sum exactly to `releasedAmount` (paisa).
    static func makeReassignmentAllocations(
        remainingGoals: [Goal],
        releasedAmount: Paisa,
        percentages: [UUID: Decimal]
    ) throws -> [GoalAllocation] {
        guard !remainingGoals.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: onlyGoalGateMessage,
                    code: .splitNotHundred
                )
            )
        }

        let orderedFractions = remainingGoals.map { percentages[$0.id] ?? 0 }
        guard OpeningSplitService.isValidHundredPercent(orderedFractions) else {
            throw AppError.validationError(
                ValidationError(
                    field: "percentages",
                    message: OpeningSplitService.shortfallMessage(for: orderedFractions)
                        ?? "Splits must total 100%.",
                    code: .splitNotHundred
                )
            )
        }

        let amounts = OpeningSplitService.allocatePaisa(
            total: max(releasedAmount, 0),
            fractions: orderedFractions
        )
        return zip(remainingGoals, zip(orderedFractions, amounts)).map { goal, pair in
            let (fraction, amount) = pair
            return GoalAllocation(
                goalId: goal.id,
                goalName: goal.name,
                amount: amount,
                percentage: fraction.rounded(scale: 4)
            )
        }
    }

    /// Creates a locked GoalDeleted History entry ("deleted / moved").
    static func createLockedDeletionEntry(
        deletedGoal: Goal,
        remainingGoals: [Goal],
        percentages: [UUID: Decimal],
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        let allocations = try makeReassignmentAllocations(
            remainingGoals: remainingGoals,
            releasedAmount: deletedGoal.savedAmount,
            percentages: percentages
        )
        return HistoryEntry(
            id: id,
            type: .goalDeleted,
            createdAt: createdAt,
            isLocked: true,
            previousBalance: nil,
            newBalance: nil,
            creditAmount: nil,
            isTyped: nil,
            fromGoalId: deletedGoal.id,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: deletedGoal.name,
            releasedAmount: deletedGoal.savedAmount,
            allocations: allocations
        )
    }

    // MARK: - Apply

    /// Applies deletion: moves money, appends History, removes goal, renormalizes standing split.
    /// - Parameter resetStandingToEqual: when true (frame 17d after mid-delete create), standing becomes equal.
    static func applyDeletion(
        to state: PersistedAppState,
        deletingGoalID: UUID,
        percentages: [UUID: Decimal],
        resetStandingToEqual: Bool = false,
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard let deletedGoal = state.goals.first(where: { $0.id == deletingGoalID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "goalId",
                    message: "Goal not found.",
                    code: .emptyName
                )
            )
        }

        let remaining = remainingGoals(deletingGoalID: deletingGoalID, from: state.goals)
        guard !remaining.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: onlyGoalGateMessage,
                    code: .splitNotHundred
                )
            )
        }

        let entry = try createLockedDeletionEntry(
            deletedGoal: deletedGoal,
            remainingGoals: remaining,
            percentages: percentages,
            id: entryID,
            createdAt: now
        )

        var next = state
        var goalsByID = Dictionary(uniqueKeysWithValues: remaining.map { ($0.id, $0) })

        for allocation in entry.allocations {
            guard var goal = goalsByID[allocation.goalId] else {
                throw AppError.validationError(
                    ValidationError(
                        field: "goalId",
                        message: "Allocation references unknown goal \(allocation.goalId).",
                        code: .splitNotHundred
                    )
                )
            }
            goal.savedAmount += allocation.amount
            goal.updatedAt = now
            goalsByID[allocation.goalId] = goal
        }

        let remainingIDs = remaining.map(\.id)
        let standing: [StandingSplit]
        if resetStandingToEqual {
            standing = StandingSplitService.equalSplits(for: remainingIDs)
        } else {
            standing = StandingSplitService.renormalize(
                splits: state.standingSplits.isEmpty
                    ? state.goals.map { StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits) }
                    : state.standingSplits,
                removingGoalID: deletingGoalID,
                remainingGoalIDs: remainingIDs
            )
        }

        let orderedRemaining = remaining.map { goalsByID[$0.id]! }
        next.goals = StandingSplitService.applyShares(to: orderedRemaining, splits: standing, now: now)
        next.standingSplits = standing
        next.history.append(entry)
        next.heldGoalChanges = next.heldGoalChanges.filter { $0.goalId != deletingGoalID }
        return next
    }

    /// Inserts a replacement / mid-delete goal (saved ₹0) and optionally resets standing to equal (17d).
    static func addGoalDuringDelete(
        to state: PersistedAppState,
        goal: Goal,
        resetStandingToEqual: Bool = true,
        now: Date = Date()
    ) -> PersistedAppState {
        var next = state
        var inserted = goal
        inserted.savedAmount = 0
        inserted.updatedAt = now
        if !next.goals.contains(where: { $0.id == inserted.id }) {
            next.goals.append(inserted)
        }

        if resetStandingToEqual {
            let ids = next.goals.map(\.id)
            let standing = StandingSplitService.equalSplits(for: ids)
            next.standingSplits = standing
            next.goals = StandingSplitService.applyShares(to: next.goals, splits: standing, now: now)
        } else if !next.standingSplits.contains(where: { $0.goalId == inserted.id }) {
            // Keep prior relative weights; new goal starts at 0% until user edits / confirm renormalizes.
            next.standingSplits.append(StandingSplit(goalId: inserted.id, percentage: 0))
        }
        return next
    }

    /// Confirm enabled when there is at least one remaining goal and reassignment totals 100%.
    static func canConfirm(
        deletingGoalID: UUID,
        goals: [Goal],
        percentages: [UUID: Decimal]
    ) -> Bool {
        let remaining = remainingGoals(deletingGoalID: deletingGoalID, from: goals)
        guard !remaining.isEmpty else { return false }
        let fractions = remaining.map { percentages[$0.id] ?? 0 }
        return OpeningSplitService.isValidHundredPercent(fractions)
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
