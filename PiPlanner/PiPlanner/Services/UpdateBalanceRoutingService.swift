import Foundation

/// Consent No Update balance sheet choice (frame 4 / 11a).
enum UpdateBalanceChoice: Equatable, Sendable {
    case manually
    case balanceSync
}

/// Navigation targets for Update balance routes (frames 4 / 4a–4e / 11a–11c).
enum UpdateBalanceRoute: Equatable, Sendable {
    case choice
    case manualAmount
    case upiPinMock
    case otherUPIApp
    case wrongPin
    case fetchedBalance
}

/// Pure routing + History shape helpers for Consent No Update balance (PIP-100).
///
/// Routes:
/// - Manually → Manual amount
/// - Balance sync + account in Paytm → UPI PIN mock → Check balance → Fetch
/// - Other UPI app (not Paytm-linked, or explicit other-app) → Manual amount only
///
/// Setup Consent persists balances via PIP-99 `LedgerFacade` (snapshot vs typed).
/// `LedgerFacade.BalanceSource` maps to PIP-98 `LedgerEngineCore.BalanceSource`.
/// Goals Sync / Update + History open→save go through PIP-102/103 `StubLedgerEngine`
/// (`processBalanceUpdate` / Save). Shape helpers / Opening writers reuse
/// `CreditEntryService` / `OpeningSplitService` / `StubLedgerService` — do not invent
/// a parallel entry writer; pure mutations live on `LedgerEngineCore`.
enum UpdateBalanceRoutingService {
    /// Maps PIP-100 typed flag ↔ `LedgerFacade.BalanceSource` → engine fetch/typed.
    static func balanceSource(isTyped: Bool) -> LedgerFacade.BalanceSource {
        isTyped ? .typedManual : .snapshotFetch
    }
    /// After Manually / Balance sync on the Update balance sheet.
    static func route(
        after choice: UpdateBalanceChoice,
        dedicatedIsPaytmLinked: Bool
    ) -> UpdateBalanceRoute {
        switch choice {
        case .manually:
            return .manualAmount
        case .balanceSync:
            return dedicatedIsPaytmLinked ? .upiPinMock : .otherUPIApp
        }
    }

    /// Frame 4c — Other UPI app continues only to Manual amount.
    static func routeAfterOtherUPIApp() -> UpdateBalanceRoute {
        .manualAmount
    }

    /// Frames 4d / 4e — retry PIN or enter manually.
    static func routeAfterWrongPin(retry: Bool) -> UpdateBalanceRoute {
        retry ? .upiPinMock : .manualAmount
    }

    /// PIN Check balance success → fetched balance screen (setup) / open credit (Goals).
    static func routeAfterPINSuccess() -> UpdateBalanceRoute {
        .fetchedBalance
    }

    /// `HistoryEntry.isTyped` for a successful balance resolution from this route.
    /// Manual (including Other→Manual) is typed; PIN / Consent Yes fetch is not.
    static func isTypedBalance(resolvedFrom route: UpdateBalanceRoute) -> Bool {
        switch route {
        case .manualAmount, .otherUPIApp, .choice, .wrongPin:
            return true
        case .upiPinMock, .fetchedBalance:
            return false
        }
    }

    // MARK: - History entry shape (same fields; `isTyped` differs)

    /// Fields every Update-balance New credit entry must populate (Manual + PIN).
    static func assertNewCreditShape(_ entry: HistoryEntry) -> Bool {
        entry.type == .newCredit
            && entry.previousBalance != nil
            && entry.newBalance != nil
            && entry.creditAmount != nil
            && entry.isTyped != nil
            && entry.fromGoalId == nil
            && entry.toGoalId == nil
            && entry.transferAmount == nil
            && entry.withdrawalAmount == nil
            && entry.deletedGoalName == nil
            && entry.releasedAmount == nil
            && !entry.allocations.isEmpty
    }

    /// Fields every setup Opening balance entry must populate (Manual + PIN + Other→Manual).
    static func assertOpeningBalanceShape(_ entry: HistoryEntry) -> Bool {
        entry.type == .openingBalance
            && entry.isLocked
            && entry.previousBalance == nil
            && entry.newBalance != nil
            && entry.creditAmount != nil
            && entry.isTyped != nil
            && entry.fromGoalId == nil
            && entry.toGoalId == nil
            && entry.transferAmount == nil
            && entry.withdrawalAmount == nil
            && entry.deletedGoalName == nil
            && entry.releasedAmount == nil
            && !entry.allocations.isEmpty
    }

    /// Open New credit via existing CreditEntryService (PIP-98 `LedgerEngineCore` owns full credit/history rules).
    static func makeOpenCreditEntry(
        goals: [Goal],
        standingSplits: [StandingSplit],
        previousBalance: Paisa,
        newBalance: Paisa,
        isTyped: Bool,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        let creditAmount = newBalance - previousBalance
        return try CreditEntryService.createOpenCreditEntry(
            goals: goals,
            standingSplits: standingSplits,
            previousBalance: previousBalance,
            newBalance: newBalance,
            creditAmount: creditAmount,
            isTyped: isTyped,
            id: id,
            createdAt: createdAt
        )
    }

    /// Locked Opening balance via existing OpeningSplitService (PIP-98 `LedgerEngineCore` for ledger formulas).
    static func makeOpeningHistoryEntry(
        goals: [Goal],
        openingBalance: Paisa,
        percentages: [UUID: Decimal],
        isTyped: Bool,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        try OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: openingBalance,
            percentages: percentages,
            id: id,
            createdAt: createdAt,
            isTyped: isTyped
        )
    }
}
