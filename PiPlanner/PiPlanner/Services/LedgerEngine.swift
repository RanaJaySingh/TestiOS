import Foundation

<<<<<<< HEAD
/// Pure ledger surface used by Goals Sync / Update (PIP-102) and History
/// open → save (PIP-103).
///
/// PIP-98 owns the full engine; until that lands, `StubLedgerEngine` adapts the
/// existing pure services (`CreditEntryService`, `GoalHeldChangeService`) so
/// Goals tab + Credit entry call sites stay engine-shaped and swap cleanly later.
=======
/// Goals Sync / Update ledger surface (PIP-102).
///
/// PIP-98 pure rules live in `LedgerEngineCore`. Goals call sites inject
/// `any LedgerEngine` (default `StubLedgerEngine`), which applies pending goal
/// edits then delegates credit deltas to `LedgerEngineCore`.
>>>>>>> 79d9f62 (PIP-98: Add pure Swift LedgerEngine + unit tests)
///
/// Distinct from PIP-99 `LedgerFacade` (Accounts/Consent opening-balance setup).
protocol LedgerEngine: Sendable {
    /// BR-6 — Sync / Update blocked while an open New credit History entry exists.
    func isSyncOrUpdateBlocked(history: [HistoryEntry]) -> Bool

    /// Open (unlocked) New credit entry, if any.
    func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry?

    /// Suggested this-credit split fractions (standing → goal share → equal).
    /// PIP-103 alias surface: same as `CreditEntryService.suggestedStandingPercentages`.
    func suggestedSplitPercentages(
        goals: [Goal],
        standingSplits: [StandingSplit]
    ) -> [UUID: Decimal]

    /// Compare / write open History entry path used by Sync (consent Yes) and
    /// Update balance (consent No). Applies pending goal edits before writing.
    func processBalanceUpdate(
        state: PersistedAppState,
        newBalance: Paisa,
        dedicatedAccountID: UUID,
        isTyped: Bool,
        id: UUID,
        createdAt: Date
    ) throws -> CreditProcessOutcome

    /// One-time Save and lock: updates goal totals, sets `customSplit`, freezes entry (PIP-103).
    func saveAndLockCredit(
        state: PersistedAppState,
        entryID: UUID,
        percentages: [UUID: Decimal],
        useThisSplitForStanding: Bool,
        now: Date
    ) throws -> PersistedAppState

    /// Create a goal while an open credit is pending (saved ₹0; totals unchanged until Save).
    func addGoalToOpenCredit(
        state: PersistedAppState,
        entryID: UUID,
        goal: Goal,
        now: Date
    ) throws -> PersistedAppState
}

extension LedgerEngine {
    /// PIP-103 / Sync open-credit alias — delegates to `processBalanceUpdate`.
    func openCreditFromFetchedBalance(
        state: PersistedAppState,
        fetchedBalance: Paisa,
        dedicatedAccountID: UUID,
        isTyped: Bool,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> CreditProcessOutcome {
        try processBalanceUpdate(
            state: state,
            newBalance: fetchedBalance,
            dedicatedAccountID: dedicatedAccountID,
            isTyped: isTyped,
            id: id,
            createdAt: createdAt
        )
    }

    /// Suggested standing split (1 goal → 100%) — PIP-103 naming.
    func suggestedStandingPercentages(
        goals: [Goal],
        standingSplits: [StandingSplit]
    ) -> [UUID: Decimal] {
        suggestedSplitPercentages(goals: goals, standingSplits: standingSplits)
    }
}

<<<<<<< HEAD
/// Adapter ledger used while PIP-98 is unmerged. Delegates to existing services;
/// owns the PIP-102 rule of applying pending goal edits before an open entry write,
/// plus PIP-103 Save / create-goal while open.
=======
/// Goals Sync/Update adapter (PIP-102). Applies pending edits, then uses
/// `LedgerEngineCore` for snapshot/typed credit deltas.
>>>>>>> 79d9f62 (PIP-98: Add pure Swift LedgerEngine + unit tests)
struct StubLedgerEngine: LedgerEngine {
    func isSyncOrUpdateBlocked(history: [HistoryEntry]) -> Bool {
        CreditEntryService.isSyncOrUpdateBlocked(history: history)
    }

    func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry? {
        LedgerEngineCore.openCreditEntry(in: history)
    }

    func suggestedSplitPercentages(
        goals: [Goal],
        standingSplits: [StandingSplit]
    ) -> [UUID: Decimal] {
        CreditEntryService.suggestedStandingPercentages(
            goals: goals,
            standingSplits: standingSplits
        )
    }

    func processBalanceUpdate(
        state: PersistedAppState,
        newBalance: Paisa,
        dedicatedAccountID: UUID,
        isTyped: Bool,
        id: UUID,
        createdAt: Date
    ) throws -> CreditProcessOutcome {
        if isSyncOrUpdateBlocked(history: state.history) {
            throw AppError.validationError(
                ValidationError(
                    field: "history",
                    message: "An open credit must be assigned before Sync or Update.",
                    code: .splitNotHundred
                )
            )
        }

        guard let dedicated = state.accounts.first(where: {
            $0.id == dedicatedAccountID || $0.isDedicated
        }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "accounts",
                    message: "Dedicated savings account not found.",
                    code: .noDedicatedAccount
                )
            )
        }

        let previous = dedicated.balance
        switch CreditEntryService.compare(previousBalance: previous, newBalance: newBalance) {
        case .same:
            return .noNewCredit(message: CreditEntryService.noNewCreditMessage)

        case .lower(let shortfall, let previousBalance, let lowerBalance):
            return .withdrawalRequired(
                shortfall: shortfall,
                previousBalance: previousBalance,
                newBalance: lowerBalance
            )

        case .higher:
            // PIP-102: pending goal edits apply before the open History entry is written
            // so suggested split uses the post-edit shares.
            let prepared = GoalHeldChangeService.applyPendingEdits(to: state, now: createdAt)
            let source: LedgerEngineCore.BalanceSource = isTyped ? .typed : .fetched
            return try LedgerEngineCore.applyBalanceDelta(
                to: prepared,
                newBalance: newBalance,
                source: source,
                dedicatedAccountID: dedicatedAccountID,
                id: id,
                createdAt: createdAt
            )
        }
    }

    func saveAndLockCredit(
        state: PersistedAppState,
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

    func addGoalToOpenCredit(
        state: PersistedAppState,
        entryID: UUID,
        goal: Goal,
        now: Date = Date()
    ) throws -> PersistedAppState {
        try CreditEntryService.addGoalToOpenCredit(
            to: state,
            entryID: entryID,
            goal: goal,
            now: now
        )
    }
}
