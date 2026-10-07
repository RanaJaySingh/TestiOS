import Combine
import Foundation

/// View model for Settings (frames 20 / 20a / 20b / 20c) — PRD R17.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var consentAutoUpdate = false
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    /// Present Consent sheet when turning Automatic balance updates On (20b).
    @Published var showConsentSheet = false
    /// Confirmation alert before Reset demo.
    @Published var showResetConfirmation = false
    /// Set after a successful reset so the host can return to Welcome (1).
    @Published private(set) var didResetDemo = false

    let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing

    var linkedAccounts: [Account] {
        SettingsService.linkedAccounts(from: accounts)
    }

    var consentSubtitle: String {
        consentAutoUpdate
            ? SettingsService.consentOnSubtitle
            : SettingsService.consentOffSubtitle
    }

    var showsUntypedGapHint: Bool {
        !consentAutoUpdate
    }

    init(
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        initialAccounts: [Account] = []
    ) {
        self.persistence = persistence
        self.formatting = formatting
        if !initialAccounts.isEmpty {
            applyAccounts(initialAccounts)
        }
    }

    func load() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let state = try await persistence.loadState()
            applyAccounts(state.accounts)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func formattedBalance(for account: Account) -> String {
        formatting.formatINR(paisa: account.balance)
    }

    func displayTitle(for account: Account) -> String {
        AccountsService.displayTitle(for: account)
    }

    func roleLabel(for account: Account) -> String {
        SettingsService.roleLabel(for: account)
    }

    func linkSubtitle(for account: Account) -> String {
        SettingsService.linkSubtitle(for: account)
    }

    /// Toggle Automatic balance updates. Off → persist immediately (20a).
    /// Off→On → reopen Consent sheet without flipping On yet (20b).
    func setAutomaticBalanceUpdates(_ enabled: Bool) {
        if SettingsService.shouldReopenConsent(
            currentAutoUpdate: consentAutoUpdate,
            turningOn: enabled
        ) {
            showConsentSheet = true
            return
        }
        if !enabled {
            consentAutoUpdate = false
            Task { await turnOffAutomaticBalanceUpdates() }
        }
    }

    /// Persist Consent Off (20a) — Goals shows Update balance.
    func turnOffAutomaticBalanceUpdates() async {
        await persistConsent(autoUpdate: false)
    }

    /// Consent sheet Yes (Settings path) — enable auto-update without re-fetching opening balance.
    func confirmConsentOn() async {
        await persistConsent(autoUpdate: true)
        showConsentSheet = false
    }

    /// Consent sheet No — remain Off; Goals keeps Update balance.
    func declineConsentFromSheet() async {
        await persistConsent(autoUpdate: false)
        showConsentSheet = false
    }

    /// Consent sheet dismissed without Yes — ensure toggle stays Off.
    func consentSheetDismissed() {
        if !consentAutoUpdate {
            showConsentSheet = false
        }
    }

    func requestResetDemo() {
        showResetConfirmation = true
    }

    /// Clears all persisted demo data and signals host to show Welcome (1).
    func confirmResetDemo() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await persistence.resetDemo()
            accounts = []
            consentAutoUpdate = false
            showResetConfirmation = false
            didResetDemo = true
        } catch {
            errorMessage = error.localizedDescription
            showResetConfirmation = false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func applyAccounts(_ accounts: [Account]) {
        self.accounts = accounts
        consentAutoUpdate = SettingsService.consentAutoUpdate(in: accounts)
    }

    private func persistConsent(autoUpdate: Bool) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            var state = try await persistence.loadState()
            let updated = SettingsService.applyingConsent(autoUpdate: autoUpdate, to: state.accounts)
            state.accounts = updated
            try await persistence.saveState(state)
            applyAccounts(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
