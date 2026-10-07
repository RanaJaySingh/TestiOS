import Foundation

/// Pure Settings helpers (frames 20 / 20a / 20b / 20c) — PRD R17.
/// Testable on Linux without SwiftUI / Combine.
enum SettingsService {
    /// Automatic balance updates subtitle when consent is On (frame 20).
    static let consentOnSubtitle =
        "PiPlanner reads this balance when you tap Sync."

    /// Automatic balance updates subtitle when consent is Off (frame 20a).
    static let consentOffSubtitle =
        "Update balance replaces Sync. Type credits yourself, or use Balance sync with your UPI PIN."

    /// Untyped-gap hint while Off (frame 20c) — next Sync after turning On arrives as one amount.
    static let untypedGapWhileOffHint =
        "Anything not typed in the meantime arrives as one amount on the next Sync."

    /// Reset demo confirmation title / message (frame 20).
    static let resetDemoTitle = "Reset demo?"
    static let resetDemoMessage =
        "Clears goals and history and returns to Welcome."
    static let resetDemoButtonTitle = "Reset demo"

    /// Post–Reset Welcome seed (PIP-108 / PIP-65) — accounts only; no goals / history.
    /// Persistence clears the JSON file; the app root reseeds via this snapshot.
    static func welcomeStateAfterDemoReset() -> PersistedAppState {
        PersistedAppState(
            accounts: DemoData.sampleAccounts,
            goals: [],
            history: [],
            standingSplits: []
        )
    }

    /// Applies `consentAutoUpdate` on the dedicated savings account only.
    static func applyingConsent(
        autoUpdate: Bool,
        to accounts: [Account]
    ) -> [Account] {
        accounts.map { account in
            var copy = account
            if copy.isDedicated {
                copy.consentAutoUpdate = autoUpdate
            }
            return copy
        }
    }

    /// Dedicated account’s consent flag (false when none dedicated).
    static func consentAutoUpdate(in accounts: [Account]) -> Bool {
        AccountsService.dedicatedAccount(in: accounts)?.consentAutoUpdate ?? false
    }

    /// Linked-account rows for Settings (dedicated first, then others).
    static func linkedAccounts(from accounts: [Account]) -> [Account] {
        let dedicated = accounts.filter(\.isDedicated)
        let others = accounts.filter { !$0.isDedicated }
        return dedicated + others
    }

    /// Role label under Linked accounts.
    static func roleLabel(for account: Account) -> String {
        if account.isDedicated {
            return "Dedicated savings"
        }
        return "Spending"
    }

    /// Paytm / link subtitle for an account row.
    static func linkSubtitle(for account: Account) -> String {
        account.isPaytmLinked ? "Linked in Paytm" : "Not linked in Paytm"
    }

    /// Goals balance action driven by consent (Sync vs Update balance).
    static func goalsBalanceAction(for accounts: [Account]) -> GoalsBalanceAction {
        GoalsTabService.balanceAction(for: accounts)
    }

    /// Whether turning the Settings toggle On should reopen Consent (20b).
    /// True when consent is currently Off and the user intends to turn On.
    static func shouldReopenConsent(currentAutoUpdate: Bool, turningOn: Bool) -> Bool {
        !currentAutoUpdate && turningOn
    }
}
