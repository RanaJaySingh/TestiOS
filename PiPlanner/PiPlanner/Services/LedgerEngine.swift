import Foundation

/// Pure ledger surface used by Goals Sync / Update (PIP-102).
///
/// PIP-98 owns the full engine; until that lands, `StubLedgerEngine` adapts the
/// existing pure services (`CreditEntryService`, `GoalHeldChangeService`) so
/// Goals tab call sites stay engine-shaped and swap cleanly later.
protocol LedgerEngine: Sendable {
    /// BR-6 — Sync / Update blocked while an open New credit History entry exists.
    func isSyncOrUpdateBlocked(history: [HistoryEntry]) -> Bool

    /// Open (unlocked) New credit entry, if any.
    func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry?

    /// Suggested this-credit split fractions (standing → goal share → equal).
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
}

/// Adapter ledger used while PIP-98 is unmerged. Delegates to existing services;
/// owns the PIP-102 rule of applying pending goal edits before an open entry write.
struct StubLedgerEngine: LedgerEngine {
    func isSyncOrUpdateBlocked(history: [HistoryEntry]) -> Bool {
        CreditEntryService.isSyncOrUpdateBlocked(history: history)
    }

    func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry? {
        CreditEntryService.openCreditEntry(in: history)
    }

    func suggestedSplitPercentages(
        goals: [Goal],
        standingSplits: [StandingSplit]
    ) -> [UUID: Decimal] {
        CreditEntryService.defaultPercentages(goals: goals, standingSplits: standingSplits)
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

        case .higher(let creditAmount, let previousBalance, let higherBalance):
            // PIP-102: pending goal edits apply before the open History entry is written
            // so suggested split uses the post-edit shares.
            let prepared = GoalHeldChangeService.applyPendingEdits(to: state, now: createdAt)
            let entry = try CreditEntryService.createOpenCreditEntry(
                goals: prepared.goals,
                standingSplits: prepared.standingSplits,
                previousBalance: previousBalance,
                newBalance: higherBalance,
                creditAmount: creditAmount,
                isTyped: isTyped,
                id: id,
                createdAt: createdAt
            )
            let next = try CreditEntryService.applyOpenCredit(
                to: prepared,
                entry: entry,
                dedicatedAccountID: dedicatedAccountID
            )
            return .openCreditCreated(state: next, entry: entry)
        }
    }
}
