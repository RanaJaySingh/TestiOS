import Combine
import Foundation

/// View model for Accounts (frame 2) — PRD R2 / R21; Spec BR-1.
@MainActor
final class AccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [Account]
    @Published private(set) var isContinuing = false
    @Published private(set) var errorMessage: String?
    /// Set after a successful Continue so the view can navigate to Consent (3).
    @Published private(set) var shouldNavigateToConsent = false

    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing

    var canContinue: Bool {
        !isContinuing && AccountsService.canContinue(with: accounts)
    }

    var statusMessage: String {
        AccountsService.statusMessage(for: accounts)
    }

    var dedicatedAccount: Account? {
        AccountsService.dedicatedAccount(in: accounts)
    }

    init(
        accounts: [Account],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.accounts = accounts
        self.persistence = persistence
        self.formatting = formatting
    }

    func displayTitle(for account: Account) -> String {
        AccountsService.displayTitle(for: account)
    }

    func formattedBalance(for account: Account) -> String {
        formatting.formatINR(paisa: account.balance)
    }

    /// Role label for demo persona rows (Savings vs Spending) without changing Account contract.
    func roleLabel(for account: Account) -> String {
        if account.bankName == "HDFC" {
            return "Savings"
        }
        if account.bankName == "SBI" {
            return "Spending"
        }
        return "Account"
    }

    /// Exclusive dedicated toggle (BR-1): ON on one turns others OFF.
    func setDedicated(accountID: UUID, isDedicated: Bool) {
        accounts = AccountsService.applyingDedicatedToggle(
            accountID: accountID,
            isDedicated: isDedicated,
            to: accounts
        )
        errorMessage = nil
        shouldNavigateToConsent = false
    }

    /// Persists dedicated selection and signals navigation to Consent when exactly one is dedicated.
    func continueToConsent() async {
        guard canContinue else { return }
        isContinuing = true
        errorMessage = nil
        defer { isContinuing = false }

        do {
            var state = try await persistence.loadState()
            state.accounts = accounts
            try await persistence.saveState(state)
            shouldNavigateToConsent = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
