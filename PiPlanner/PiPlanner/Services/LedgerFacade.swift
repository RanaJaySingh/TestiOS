import Foundation

/// PIP-99 stub until PIP-98 `LedgerEngine` merges.
///
/// Setup Consent / opening-balance paths call this instead of inventing ledger
/// mutations inline. When PIP-98 lands, replace bodies with `LedgerEngine`
/// snapshot / typed-delta APIs — call sites stay stable.
enum LedgerFacade {
    /// How the opening balance was obtained (reserved for PIP-98 History / delta).
    enum BalanceSource: Equatable, Sendable {
        /// Consent Yes fetch or UPI PIN success — bank snapshot.
        case snapshotFetch
        /// Manual typed amount — typed credit / opening later.
        case typedManual
    }

    /// Applies opening balance + consent on the **dedicated** account only.
    /// Spending accounts are left unchanged (balances stay Accounts-only).
    static func applySetupOpeningBalance(
        to accounts: [Account],
        balancePaisa: Paisa,
        consentAutoUpdate: Bool,
        source: BalanceSource
    ) -> [Account] {
        _ = source // PIP-98: snapshot vs typed drives History / delta.
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
