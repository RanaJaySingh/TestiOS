import Foundation

/// Pure held-edit logic for Goal detail / edit (PRD R11 / R24, Spec BR-4).
/// Edits update goal parameters for the next credit and never rewrite locked History.
enum GoalHeldChangeService {
    /// Toast copy — PIP-97 / standing-split wording (applies at the next credit).
    static let toastMessage = "Change saved. Applies at the next credit."

    /// Later-view held info — design frame 13g.
    static let heldInfoMessage =
        "Edit saved. Changes apply at the next credit. Earlier history stays as it is."

    /// Status copy aligned with Goals tab (PIP-45 / frames 9 / 11 / 14).
    static func statusLabel(for status: GoalStatus) -> String {
        switch status {
        case .onTrack:
            return "On track"
        case .behind:
            return "Behind"
        }
    }

    // MARK: - Apply / diff

    /// Applies editable fields; `savedAmount` is always preserved from `goal`.
    static func applyEdit(to goal: Goal, draft: GoalEditDraft, now: Date = Date()) -> Goal {
        Goal(
            id: goal.id,
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: draft.targetPaisa,
            startDate: draft.startDate,
            endDate: draft.endDate,
            inflationRate: draft.inflationRate,
            savedAmount: goal.savedAmount,
            shareOfNewCredits: draft.shareOfNewCredits,
            createdAt: goal.createdAt,
            updatedAt: now
        )
    }

    /// Returns a held-change record when editable fields differ; ignores savedAmount-only diffs.
    static func makeHeldChange(
        from goal: Goal,
        to draft: GoalEditDraft,
        now: Date = Date(),
        id: UUID = UUID()
    ) -> HeldGoalChange? {
        let pendingName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingTarget = draft.targetPaisa
        let fieldsChanged =
            pendingName != goal.name
            || pendingTarget != goal.targetAmount
            || draft.startDate != goal.startDate
            || draft.endDate != goal.endDate
            || draft.inflationRate != goal.inflationRate
            || draft.shareOfNewCredits != goal.shareOfNewCredits

        guard fieldsChanged else { return nil }

        return HeldGoalChange(
            id: id,
            goalId: goal.id,
            savedAt: now,
            previousName: goal.name,
            pendingName: pendingName,
            previousTargetAmount: goal.targetAmount,
            pendingTargetAmount: pendingTarget,
            previousShareOfNewCredits: goal.shareOfNewCredits,
            pendingShareOfNewCredits: draft.shareOfNewCredits,
            previousInflationRate: goal.inflationRate,
            pendingInflationRate: draft.inflationRate,
            previousStartDate: goal.startDate,
            pendingStartDate: draft.startDate,
            previousEndDate: goal.endDate,
            pendingEndDate: draft.endDate
        )
    }

    // MARK: - Held-change list

    static func record(_ change: HeldGoalChange, in changes: [HeldGoalChange]) -> [HeldGoalChange] {
        var next = changes.filter { $0.goalId != change.goalId }
        next.append(change)
        return next
    }

    static func hasHeldChange(goalId: UUID, in changes: [HeldGoalChange]) -> Bool {
        changes.contains { $0.goalId == goalId }
    }

    static func heldChange(goalId: UUID, in changes: [HeldGoalChange]) -> HeldGoalChange? {
        changes.first { $0.goalId == goalId }
    }

    /// Cleared when the next credit applies (PIP-47 / PIP-102).
    static func clear(goalId: UUID, in changes: [HeldGoalChange]) -> [HeldGoalChange] {
        changes.filter { $0.goalId != goalId }
    }

    static func clearAll() -> [HeldGoalChange] { [] }

    /// Applies every pending goal edit onto goals + standing shares, then clears
    /// `heldGoalChanges`. Called by Goals Sync / Update **before** writing an open
    /// History entry so suggested split uses post-edit percentages (PIP-102).
    /// Idempotent when goals were already mutated at edit time (PIP-49).
    static func applyPendingEdits(
        to state: PersistedAppState,
        now: Date = Date()
    ) -> PersistedAppState {
        guard !state.heldGoalChanges.isEmpty else { return state }

        var next = state
        var goalsByID = Dictionary(uniqueKeysWithValues: next.goals.map { ($0.id, $0) })

        for change in next.heldGoalChanges {
            guard var goal = goalsByID[change.goalId] else { continue }
            goal = Goal(
                id: goal.id,
                name: change.pendingName,
                targetAmount: change.pendingTargetAmount,
                startDate: change.pendingStartDate,
                endDate: change.pendingEndDate,
                inflationRate: change.pendingInflationRate,
                savedAmount: goal.savedAmount,
                shareOfNewCredits: change.pendingShareOfNewCredits,
                createdAt: goal.createdAt,
                updatedAt: now
            )
            goalsByID[change.goalId] = goal
            next.standingSplits = updatedStandingSplits(
                next.standingSplits,
                goalId: change.goalId,
                share: change.pendingShareOfNewCredits
            )
        }

        next.goals = next.goals.map { goalsByID[$0.id] ?? $0 }

        // When every goal has a pending or live share, rebuild standing from goal
        // shares if they still sum to 100% — keeps suggested split coherent.
        let shareMap = Dictionary(uniqueKeysWithValues: next.goals.map {
            ($0.id, $0.shareOfNewCredits)
        })
        let orderedShares = next.goals.map { shareMap[$0.id] ?? 0 }
        if !next.goals.isEmpty, OpeningSplitService.isValidHundredPercent(orderedShares) {
            next.standingSplits = next.goals.map {
                StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits)
            }
        }

        next.heldGoalChanges = clearAll()
        return next
    }

    // MARK: - History

    /// Newest-first entries that allocate to or transfer involving the goal.
    static func relatedHistory(goalId: UUID, in history: [HistoryEntry]) -> [HistoryEntry] {
        history
            .filter { entry in
                if entry.allocations.contains(where: { $0.goalId == goalId }) {
                    return true
                }
                if entry.fromGoalId == goalId || entry.toGoalId == goalId {
                    return true
                }
                return false
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Updates standing split percentage for the edited goal when present.
    static func updatedStandingSplits(
        _ splits: [StandingSplit],
        goalId: UUID,
        share: Decimal
    ) -> [StandingSplit] {
        guard splits.contains(where: { $0.goalId == goalId }) else {
            return splits
        }
        return splits.map { split in
            guard split.goalId == goalId else { return split }
            return StandingSplit(goalId: goalId, percentage: share)
        }
    }

    /// Full commit: update goal + standing share, record held change, leave history untouched.
    static func commitEdit(
        goal: Goal,
        draft: GoalEditDraft,
        history: [HistoryEntry],
        heldChanges: [HeldGoalChange],
        standingSplits: [StandingSplit],
        now: Date = Date(),
        changeID: UUID = UUID()
    ) -> GoalEditCommitResult {
        let updatedGoal = applyEdit(to: goal, draft: draft, now: now)
        var nextHeld = heldChanges
        if let change = makeHeldChange(from: goal, to: draft, now: now, id: changeID) {
            nextHeld = record(change, in: heldChanges)
        }
        let nextSplits = updatedStandingSplits(
            standingSplits,
            goalId: goal.id,
            share: updatedGoal.shareOfNewCredits
        )
        return GoalEditCommitResult(
            updatedGoal: updatedGoal,
            history: history,
            heldChanges: nextHeld,
            updatedStandingSplits: nextSplits,
            toastMessage: toastMessage
        )
    }

    // MARK: - History row presentation helpers

    static func historyTypeLabel(for type: HistoryEntryType) -> String {
        switch type {
        case .openingBalance: return "Opening balance"
        case .newCredit: return "New credit"
        case .transfer: return "Transfer"
        case .withdrawal: return "Withdrawal"
        case .goalDeleted: return DeleteGoalService.historyTitle
        }
    }

    static func amountPaisa(for entry: HistoryEntry, goalId: UUID) -> Paisa? {
        if let allocation = entry.allocations.first(where: { $0.goalId == goalId }) {
            return allocation.amount
        }
        if entry.type == .transfer {
            return entry.transferAmount
        }
        return entry.creditAmount ?? entry.withdrawalAmount ?? entry.releasedAmount
    }
}
