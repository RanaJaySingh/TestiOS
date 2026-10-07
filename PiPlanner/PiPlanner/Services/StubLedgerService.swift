import Foundation

/// PIP-101 Opening-lock path (keep-both with PIP-98 `LedgerEngineCore`).
///
/// Consent / account balance setup stays on `LedgerFacade`. Opening History + standing
/// splits go through tip `UpdateBalanceRoutingService.makeOpeningHistoryEntry` (isTyped
/// shape from PIP-100) then `OpeningSplitService.applyOpeningLock`. Credit/history
/// mutations after setup live on `LedgerEngineCore` — do not duplicate Opening here.
enum StubLedgerService {
    /// Locks opening balance: History entry + standing splits + goal saved amounts.
    static func lockOpeningBalance(
        to state: PersistedAppState,
        goals: [Goal],
        openingBalance: Paisa,
        percentages: [UUID: Decimal],
        isTyped: Bool = true,
        entryID: UUID = UUID(),
        createdAt: Date = Date(),
        now: Date = Date()
    ) throws -> (PersistedAppState, HistoryEntry) {
        let entry = try UpdateBalanceRoutingService.makeOpeningHistoryEntry(
            goals: goals,
            openingBalance: openingBalance,
            percentages: percentages,
            isTyped: isTyped,
            id: entryID,
            createdAt: createdAt
        )
        var next = state
        if next.goals.isEmpty {
            next.goals = goals
        }
        next = try OpeningSplitService.applyOpeningLock(to: next, entry: entry, now: now)
        return (next, entry)
    }

    /// One-goal skip: 100% standing split + locked Opening History without a split UI.
    static func lockSingleGoalOpening(
        to state: PersistedAppState,
        goals: [Goal],
        openingBalance: Paisa,
        isTyped: Bool = true,
        entryID: UUID = UUID(),
        createdAt: Date = Date(),
        now: Date = Date()
    ) throws -> (PersistedAppState, HistoryEntry) {
        guard goals.count == 1, let goal = goals.first else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "Single-goal opening skip requires exactly one goal.",
                    code: .splitNotHundred
                )
            )
        }
        return try lockOpeningBalance(
            to: state,
            goals: goals,
            openingBalance: openingBalance,
            percentages: OpeningSplitService.singleGoalPercentages(goalID: goal.id),
            isTyped: isTyped,
            entryID: entryID,
            createdAt: createdAt,
            now: now
        )
    }
}
