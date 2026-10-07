import Foundation

/// Pure ledger rules engine (PIP-98) — Day 1 APIs for Spec ledger rules.
///
/// Linux-testable without SwiftUI. Money is `Int64` paisa. State mutations return a new
/// `PersistedAppState` (existing services under the hood). Inflation / required-savings
/// formulas delegate to tip `GoalInflationFormulas` (PIP-97) — single source.
enum LedgerEngineCore {
    /// How a balance snapshot was obtained (fetch sync vs typed Update).
    enum BalanceSource: String, Equatable, Sendable {
        case fetched
        case typed

        var isTyped: Bool { self == .typed }
    }

    /// Point-in-time dedicated balance observation for delta comparison.
    struct BalanceSnapshot: Equatable, Sendable {
        var previousBalance: Paisa
        var newBalance: Paisa
        var source: BalanceSource
    }

    // MARK: - Calendar / formulas (→ GoalInflationFormulas PIP-97)

    /// Whole calendar months from `start` to `end` (never negative).
    static func monthsBetween(start: Date, end: Date, calendar: Calendar = .gregorianUTC) -> Int {
        GoalInflationFormulas.monthsBetween(start: start, end: end, calendar: calendar)
    }

    /// Years as `months / 12` for inflation compounding.
    static func yearsFromMonths(start: Date, end: Date, calendar: Calendar = .gregorianUTC) -> Double {
        GoalInflationFormulas.yearsFromMonths(
            GoalInflationFormulas.monthsBetween(start: start, end: end, calendar: calendar)
        )
    }

    /// `target × (1 + inflation) ^ (months from start to end / 12)`
    static func adjustedTargetPaisa(
        targetPaisa: Paisa,
        inflationRate: Decimal,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: targetPaisa,
            inflationRate: inflationRate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )
    }

    /// Required monthly savings: `(adjustedTarget − currentSaving) / monthsRemaining`
    static func requiredSavingsPaisa(
        adjustedTarget: Paisa,
        currentSaving: Paisa,
        endDate: Date,
        asOf: Date = Date(),
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: adjustedTarget,
            currentSaving: currentSaving,
            endDate: endDate,
            asOf: asOf,
            calendar: calendar
        )
    }

    /// Convenience over a `Goal` using shared inflation formulas.
    static func requiredSavingsPaisa(
        for goal: Goal,
        asOf: Date = Date(),
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        let adjusted = adjustedTargetPaisa(
            targetPaisa: goal.targetAmount,
            inflationRate: goal.inflationRate,
            startDate: goal.startDate,
            endDate: goal.endDate,
            calendar: calendar
        )
        return requiredSavingsPaisa(
            adjustedTarget: adjusted,
            currentSaving: goal.savedAmount,
            endDate: goal.endDate,
            asOf: asOf,
            calendar: calendar
        )
    }

    /// On-track when saved ≥ expected cumulative required savings since start.
    static func status(
        for goal: Goal,
        asOf: Date = Date(),
        calendar: Calendar = .gregorianUTC
    ) -> GoalStatus {
        let monthly = requiredSavingsPaisa(for: goal, asOf: asOf, calendar: calendar)
        let elapsed = max(monthsBetween(start: goal.startDate, end: asOf, calendar: calendar), 0)
        let expectedSaved = monthly * Paisa(elapsed)
        if goal.savedAmount >= expectedSaved {
            return .onTrack
        }
        return .behind(shortfall: expectedSaved - goal.savedAmount)
    }

    // MARK: - Snapshot / delta (fetch vs typed)

    /// Compare previous dedicated balance to a new snapshot (R7 / R26 / 10b).
    static func compare(_ snapshot: BalanceSnapshot) -> BalanceCompareResult {
        CreditEntryService.compare(
            previousBalance: snapshot.previousBalance,
            newBalance: snapshot.newBalance
        )
    }

    /// Apply fetched or typed balance: open credit, no-op, or withdrawal-required.
    static func applyBalanceDelta(
        to state: PersistedAppState,
        newBalance: Paisa,
        source: BalanceSource,
        dedicatedAccountID: UUID,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> CreditProcessOutcome {
        try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: newBalance,
            dedicatedAccountID: dedicatedAccountID,
            isTyped: source.isTyped,
            id: id,
            createdAt: createdAt
        )
    }

    // MARK: - History: open → save; append-only slices

    /// Chronological locked slices (immutable after save).
    static func lockedSlices(in history: [HistoryEntry]) -> [HistoryEntry] {
        history
            .filter(\.isLocked)
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Open New credit entry awaiting assign / save (if any).
    static func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry? {
        CreditEntryService.openCreditEntry(in: history)
    }

    /// True when every previously locked entry is byte-equal in `after`, and history only grew
    /// by appends (plus at most one open→locked transition for the same id).
    static func isAppendOnlyMutation(before: [HistoryEntry], after: [HistoryEntry]) -> Bool {
        let beforeLocked = Dictionary(uniqueKeysWithValues: before.filter(\.isLocked).map { ($0.id, $0) })
        for (id, prior) in beforeLocked {
            guard let next = after.first(where: { $0.id == id }), next == prior else {
                return false
            }
        }

        let beforeIDs = before.map(\.id)
        let afterIDs = after.map(\.id)
        // Relative order of prior ids preserved as a subsequence.
        var cursor = afterIDs.startIndex
        for id in beforeIDs {
            guard let found = afterIDs[cursor...].firstIndex(of: id) else {
                return false
            }
            cursor = afterIDs.index(after: found)
        }
        return after.count >= before.count
    }

    /// Open → Save and lock (BR-5). History grows or locks in place; locked slices stay immutable.
    static func saveOpenCredit(
        to state: PersistedAppState,
        entryID: UUID,
        percentages: [UUID: Decimal],
        useThisSplitForStanding: Bool,
        now: Date = Date()
    ) throws -> PersistedAppState {
        try CreditEntryService.applyCreditLock(
            to: state,
            entryID: entryID,
            percentages: percentages,
            useThisSplitForStanding: useThisSplitForStanding,
            now: now
        )
    }

    // MARK: - Standing split (1 goal = 100%)

    /// Single goal always receives 100% of new credits.
    static func singleGoalStandingPercentages(goalID: UUID) -> [UUID: Decimal] {
        StandingSplitService.singleGoalPercentages(goalID: goalID)
    }

    /// Standing for exactly one goal → 100%; otherwise applies `percentages` (must total 100%).
    static func applyStanding(
        to state: PersistedAppState,
        percentages: [UUID: Decimal]? = nil,
        now: Date = Date()
    ) throws -> PersistedAppState {
        if state.goals.count == 1 {
            return try StandingSplitService.applySingleGoalSkip(to: state, now: now)
        }
        guard let percentages else {
            throw AppError.validationError(
                ValidationError(
                    field: "percentages",
                    message: "Standing split percentages are required when multiple goals exist.",
                    code: .splitNotHundred
                )
            )
        }
        return try StandingSplitService.applyStandingSplit(
            to: state,
            percentages: percentages,
            now: now
        )
    }

    // MARK: - Create / update (pending) / transfer / delete / withdrawal

    /// Creates a goal (saved ₹0). With one goal after insert, standing becomes 100%.
    static func createGoal(
        to state: PersistedAppState,
        name: String,
        targetPaisa: Paisa,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal = GoalValidationService.defaultInflationRate,
        shareOfNewCredits: Decimal? = nil,
        id: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard GoalValidationService.canSave(
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate
        ) else {
            let errors = GoalValidationService.validationErrors(
                name: name,
                targetPaisa: targetPaisa,
                startDate: startDate,
                endDate: endDate
            )
            throw AppError.validationError(
                errors.first ?? ValidationError(
                    field: "goal",
                    message: "Goal is invalid.",
                    code: .emptyName
                )
            )
        }

        let share: Decimal
        if let shareOfNewCredits {
            share = shareOfNewCredits
        } else if state.goals.isEmpty {
            share = 1
        } else {
            share = 0
        }

        let goal = GoalValidationService.makeGoal(
            id: id,
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate,
            inflationRate: inflationRate,
            shareOfNewCredits: share,
            savedAmount: 0,
            now: now
        )

        var next = state
        next.goals.append(goal)

        if next.goals.count == 1 {
            return try StandingSplitService.applySingleGoalSkip(to: next, now: now)
        }

        // Keep prior standing weights; new goal at 0% until caller sets standing.
        if !next.standingSplits.contains(where: { $0.goalId == goal.id }) {
            next.standingSplits.append(StandingSplit(goalId: goal.id, percentage: 0))
        }
        return next
    }

    /// Pending goal edit (held until next credit). History locked slices unchanged (BR-4).
    static func updateGoalPending(
        to state: PersistedAppState,
        goalID: UUID,
        draft: GoalEditDraft,
        now: Date = Date(),
        changeID: UUID = UUID()
    ) throws -> PersistedAppState {
        guard let goal = state.goals.first(where: { $0.id == goalID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "goalId",
                    message: "Goal not found.",
                    code: .emptyName
                )
            )
        }

        let result = GoalHeldChangeService.commitEdit(
            goal: goal,
            draft: draft,
            history: state.history,
            heldChanges: state.heldGoalChanges,
            standingSplits: state.standingSplits,
            now: now,
            changeID: changeID
        )

        var next = state
        next.goals = next.goals.map { $0.id == goalID ? result.updatedGoal : $0 }
        next.history = result.history
        next.heldGoalChanges = result.heldChanges
        next.standingSplits = result.updatedStandingSplits
        return next
    }

    static func transfer(
        to state: PersistedAppState,
        fromGoalId: UUID,
        toGoalId: UUID,
        amountPaisa: Paisa,
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        try TransferService.applyTransfer(
            to: state,
            fromGoalId: fromGoalId,
            toGoalId: toGoalId,
            amountPaisa: amountPaisa,
            entryID: entryID,
            now: now
        )
    }

    static func deleteRedistributing(
        to state: PersistedAppState,
        deletingGoalID: UUID,
        percentages: [UUID: Decimal],
        resetStandingToEqual: Bool = false,
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        try DeleteGoalService.applyDeletion(
            to: state,
            deletingGoalID: deletingGoalID,
            percentages: percentages,
            resetStandingToEqual: resetStandingToEqual,
            entryID: entryID,
            now: now
        )
    }

    static func withdraw(
        to state: PersistedAppState,
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        reductions: [UUID: Paisa],
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        try WithdrawalService.applyWithdrawal(
            to: state,
            shortfall: shortfall,
            previousBalance: previousBalance,
            newBalance: newBalance,
            reductions: reductions,
            entryID: entryID,
            now: now
        )
    }
}

extension Calendar {
    /// Alias for PIP-97 `gregorianUTC` — ledger tests share the same calendar.
    static var ledger: Calendar { .gregorianUTC }
}
