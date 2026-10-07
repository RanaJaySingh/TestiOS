import Foundation

/// Dedicated-account selection helpers (PRD R2 / R21, Spec BR-1).
enum AccountsService {
    /// Exactly one account must be dedicated before Continue (BR-1).
    static func hasExactlyOneDedicated(_ accounts: [Account]) -> Bool {
        dedicatedCount(accounts) == 1
    }

    static func dedicatedCount(_ accounts: [Account]) -> Int {
        accounts.filter(\.isDedicated).count
    }

    static func dedicatedAccount(in accounts: [Account]) -> Account? {
        guard hasExactlyOneDedicated(accounts) else { return nil }
        return accounts.first(where: \.isDedicated)
    }

    /// Continue is enabled only when exactly one account is dedicated (BR-1).
    static func canContinue(with accounts: [Account]) -> Bool {
        hasExactlyOneDedicated(accounts)
    }

    /// Applies exclusive dedicated toggle: turning one ON turns all others OFF.
    /// Turning the dedicated account OFF leaves none dedicated.
    static func applyingDedicatedToggle(
        accountID: UUID,
        isDedicated: Bool,
        to accounts: [Account]
    ) -> [Account] {
        accounts.map { account in
            var updated = account
            if account.id == accountID {
                updated.isDedicated = isDedicated
            } else if isDedicated {
                updated.isDedicated = false
            }
            return updated
        }
    }

    /// Status copy for None dedicated vs One dedicated.
    static func statusMessage(for accounts: [Account]) -> String {
        switch dedicatedCount(accounts) {
        case 0:
            return "Select exactly one dedicated savings account to continue."
        case 1:
            if let dedicated = dedicatedAccount(in: accounts) {
                return "\(displayTitle(for: dedicated)) is your dedicated savings."
            }
            return "Dedicated savings selected."
        default:
            // Defensive — exclusivity should prevent this.
            return "Only one account can be dedicated. Turn extras off."
        }
    }

    static func displayTitle(for account: Account) -> String {
        "\(account.bankName) \(account.maskedNumber)"
    }

    // MARK: - Roles / spending visibility (PIP-99)

    /// Row role on Accounts (frame 2). Dedicated wins; else demo Savings / Spending.
    static func roleLabel(for account: Account) -> String {
        if account.isDedicated {
            return "Dedicated savings"
        }
        switch account.bankName {
        case "HDFC":
            return "Savings"
        case "SBI":
            return "Spending"
        default:
            return "Account"
        }
    }

    /// Non-dedicated accounts are spending (R21 / R25) — unretracked for credits.
    static func isSpendingAccount(_ account: Account) -> Bool {
        !account.isDedicated
    }

    /// Goals / Sync / History use dedicated only. Spending balances stay on Accounts.
    static func tracksBalanceOutsideAccounts(_ account: Account) -> Bool {
        account.isDedicated
    }

    /// Balances that may appear outside Accounts (dedicated savings only).
    static func balancesTrackedOutsideAccounts(in accounts: [Account]) -> [Account] {
        accounts.filter(tracksBalanceOutsideAccounts)
    }
}
