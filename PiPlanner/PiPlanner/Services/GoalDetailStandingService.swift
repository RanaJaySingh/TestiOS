import Foundation

/// PIP-105 — Goal detail held edits + Standing split when a second goal is added.
///
/// Wraps tip `LedgerEngineCore.updateGoalPending` / `createGoal` / standing helpers so
/// Goal form (edit) and New goal can share one Linux-testable path.
enum GoalDetailStandingService {
    /// Result of committing a held Goal form edit (applies at next credit).
    struct HeldEditResult: Equatable, Sendable {
        var state: PersistedAppState
        var commit: GoalEditCommitResult
    }

    /// Result of creating a goal from Goals → New goal / Goal form.
    struct AddGoalResult: Equatable, Sendable {
        var state: PersistedAppState
        /// Present Standing split editor when resulting count ≥ 2 (1 goal = 100% skip).
        var shouldPresentStandingSplit: Bool
        var createdGoalID: UUID
    }

    /// Standing editor only when two or more goals exist (R12 / frame 15).
    static func shouldPresentStandingSplit(goalCount: Int) -> Bool {
        StandingSplitService.shouldPresentEditor(goalCount: goalCount)
    }

    /// Builds an edit draft from Goal form fields (saved amount stays locked from `goal`).
    static func editDraft(
        fromName name: String,
        targetRupeeDigits: String,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal,
        shareOfNewCredits: Decimal,
        lockedSavedAmount: Paisa
    ) -> GoalEditDraft {
        return GoalEditDraft(
            name: name,
            targetRupeeDigits: targetRupeeDigits,
            startDate: startDate,
            endDate: endDate,
            inflationRate: inflationRate,
            shareOfNewCredits: shareOfNewCredits,
            savedAmount: lockedSavedAmount
        )
    }

    /// Held edit via engine pending path — History locked slices unchanged (BR-4).
    static func commitHeldEdit(
        to state: PersistedAppState,
        goalID: UUID,
        draft: GoalEditDraft,
        now: Date = Date(),
        changeID: UUID = UUID()
    ) throws -> HeldEditResult {
        let next = try LedgerEngineCore.updateGoalPending(
            to: state,
            goalID: goalID,
            draft: draft,
            now: now,
            changeID: changeID
        )
        guard let updated = next.goals.first(where: { $0.id == goalID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "goalId",
                    message: "Goal not found after pending edit.",
                    code: .emptyName
                )
            )
        }
        let commit = GoalEditCommitResult(
            updatedGoal: updated,
            history: next.history,
            heldChanges: next.heldGoalChanges,
            updatedStandingSplits: next.standingSplits,
            toastMessage: GoalHeldChangeService.toastMessage
        )
        return HeldEditResult(state: next, commit: commit)
    }

    /// Creates a goal (saved ₹0). One goal → standing 100% via engine; two+ → present Standing split.
    static func addGoal(
        to state: PersistedAppState,
        name: String,
        targetPaisa: Paisa,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal = GoalValidationService.defaultInflationRate,
        shareOfNewCredits: Decimal? = nil,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws -> AddGoalResult {
        let next = try LedgerEngineCore.createGoal(
            to: state,
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate,
            inflationRate: inflationRate,
            shareOfNewCredits: shareOfNewCredits,
            id: id,
            now: now
        )
        return AddGoalResult(
            state: next,
            shouldPresentStandingSplit: shouldPresentStandingSplit(goalCount: next.goals.count),
            createdGoalID: id
        )
    }
}
