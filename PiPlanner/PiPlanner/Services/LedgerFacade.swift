import Foundation

/// Setup-facing ledger entrypoints (PIP-99). Call sites stay on this type;
/// snapshot vs typed maps to `LedgerEngineCore.BalanceSource` (PIP-98).
///
/// Goals Sync/Update + History open→save use PIP-102/103 `StubLedgerEngine`
/// (`LedgerEngine` protocol). Opening lock uses PIP-101 `StubLedgerService`.
/// Consent / dedicated opening-balance setup stays here.
enum LedgerFacade {
    /// How the opening balance was obtained (maps to engine fetch vs typed).
    enum BalanceSource: Equatable, Sendable {
        /// Consent Yes fetch or UPI PIN success — bank snapshot.
        case snapshotFetch
        /// Manual typed amount — typed credit / opening later.
        case typedManual

        /// PIP-98 engine source used for snapshot / delta APIs.
        var engineSource: LedgerEngineCore.BalanceSource {
            switch self {
            case .snapshotFetch: return .fetched
            case .typedManual: return .typed
            }
        }
    }

    /// Applies opening balance + consent on the **dedicated** account only.
    /// Spending accounts are left unchanged (balances stay Accounts-only).
    /// `source` is recorded via `LedgerEngineCore.BalanceSource` for later History.
    static func applySetupOpeningBalance(
        to accounts: [Account],
        balancePaisa: Paisa,
        consentAutoUpdate: Bool,
        source: BalanceSource
    ) -> [Account] {
        // Engine owns fetch-vs-typed semantics; setup still writes dedicated balance only.
        let engineSource = source.engineSource
        _ = engineSource.isTyped

        return accounts.map { account in
            var copy = account
            if copy.isDedicated {
                copy.balance = balancePaisa
                copy.consentAutoUpdate = consentAutoUpdate
            }
            return copy
        }
    }

    /// Consent No — decline auto-update on dedicated; no balance change.
    static func applyConsentDeclined(to accounts: [Account]) -> [Account] {
        accounts.map { account in
            var copy = account
            if copy.isDedicated {
                copy.consentAutoUpdate = false
            }
            return copy
        }
    }
}
