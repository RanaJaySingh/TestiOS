import Combine
import Foundation

/// Outcome of a UPI PIN check (frames 4b / 4d / 4e).
enum UPIPinCheckOutcome: Equatable, Sendable {
    case success(Paisa)
    case wrongPin
    case cancelled
    case otherApp
}

    /// View model for Consent + balance entry (frames 3–4e) — PRD R3 / R4; Spec §3.3 / PIP-99.
@MainActor
final class ConsentViewModel: ObservableObject {
    @Published private(set) var accounts: [Account]
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var resolvedBalance: Paisa?
    @Published private(set) var consentAutoUpdate = false
    @Published private(set) var pinDigits = ""
    @Published private(set) var lastPinOutcome: UPIPinCheckOutcome?
    /// Digit-only rupee amount typed on Manual (4a).
    @Published var manualRupeeDigits = ""

    private let persistence: any PersistenceServicing
    private let balanceSync: any BalanceSyncServicing
    private let formatting: any FormattingServicing
    /// Ledger mutations go through `LedgerFacade` until PIP-98 `LedgerEngine` lands.

    var dedicatedAccount: Account? {
        AccountsService.dedicatedAccount(in: accounts)
    }

    var dedicatedAccountTitle: String? {
        dedicatedAccount.map { AccountsService.displayTitle(for: $0) }
    }

    var manualAmountPaisa: Paisa {
        ConsentService.paisa(fromRupeeDigits: manualRupeeDigits)
    }

    var canContinueManual: Bool {
        !isWorking && ConsentService.canContinueManual(amountPaisa: manualAmountPaisa)
    }

    var formattedManualAmount: String {
        formatting.formatINR(paisa: manualAmountPaisa)
    }

    var formattedResolvedBalance: String {
        formatting.formatINR(paisa: resolvedBalance ?? 0)
    }

    var canCheckPIN: Bool {
        !isWorking && ConsentService.isCompletePIN(pinDigits)
    }

    init(
        accounts: [Account],
        persistence: any PersistenceServicing,
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(),
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.accounts = accounts
        self.persistence = persistence
        self.balanceSync = balanceSync
        self.formatting = formatting
    }

    /// Refresh accounts from Accounts screen before Consent actions.
    func updateAccounts(_ accounts: [Account]) {
        self.accounts = accounts
        errorMessage = nil
    }

    // MARK: - Consent (3)

    /// Yes path — fetch demo balance (3a), persist `consentAutoUpdate = true`.
    @discardableResult
    func chooseConsentYes() async -> Paisa? {
        guard let dedicated = dedicatedAccount else {
            errorMessage = "Select a dedicated savings account first."
            return nil
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let result = await balanceSync.fetchBalance(accountId: dedicated.id)
        switch result {
        case .success(let paisa):
            consentAutoUpdate = true
            resolvedBalance = paisa
            await persistConsentAndBalance(paisa: paisa, autoUpdate: true, isTyped: false)
            return paisa
        case .failure:
            errorMessage = AppError.syncError(.networkError).localizedDescription
            return nil
        }
    }

    /// No path — decline auto-update; caller shows Update balance sheet (4).
    func chooseConsentNo() {
        consentAutoUpdate = false
        errorMessage = nil
        resolvedBalance = nil
        Task { await persistConsentFlag(autoUpdate: false) }
    }

    // MARK: - Manual (4a)

    func setManualRupeeDigits(_ digits: String) {
        manualRupeeDigits = digits.filter(\.isNumber)
    }

    /// Confirm typed amount → resolved balance for next setup step.
    @discardableResult
    func continueManual() async -> Paisa? {
        guard canContinueManual else { return nil }
        let paisa = manualAmountPaisa
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        consentAutoUpdate = false
        resolvedBalance = paisa
        await persistConsentAndBalance(paisa: paisa, autoUpdate: false, isTyped: true)
        return paisa
    }

    // MARK: - UPI PIN (4b / 4d / 4e)

    func appendPINDigit(_ digit: String) {
        guard digit.count == 1, digit.first?.isNumber == true, pinDigits.count < 4 else { return }
        pinDigits += digit
        lastPinOutcome = nil
        errorMessage = nil
    }

    func deletePINDigit() {
        guard !pinDigits.isEmpty else { return }
        pinDigits.removeLast()
        lastPinOutcome = nil
        errorMessage = nil
    }

    func clearPIN() {
        pinDigits = ""
        lastPinOutcome = nil
        errorMessage = nil
    }

    /// Check balance with demo PIN. Success → resolved balance; wrong → retry/manual (4d/4e).
    @discardableResult
    func checkBalanceWithPIN() async -> UPIPinCheckOutcome {
        guard canCheckPIN else { return .wrongPin }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let result = await balanceSync.verifyUPIPin(pin: pinDigits)
        switch result {
        case .success(let paisa):
            consentAutoUpdate = false
            resolvedBalance = paisa
            await persistConsentAndBalance(paisa: paisa, autoUpdate: false, isTyped: false)
            let outcome = UPIPinCheckOutcome.success(paisa)
            lastPinOutcome = outcome
            return outcome
        case .failure(let error):
            switch error {
            case .wrongPin:
                lastPinOutcome = .wrongPin
                errorMessage = "Incorrect PIN. Try again or enter the balance manually."
                return .wrongPin
            case .cancelled:
                lastPinOutcome = .cancelled
                return .cancelled
            case .otherApp:
                lastPinOutcome = .otherApp
                return .otherApp
            }
        }
    }

    func cancelPIN() -> UPIPinCheckOutcome {
        clearPIN()
        lastPinOutcome = .cancelled
        return .cancelled
    }

    /// Frame 4c — force manual entry path.
    func accountOnOtherUPIApp() -> UPIPinCheckOutcome {
        clearPIN()
        lastPinOutcome = .otherApp
        return .otherApp
    }

    func retryPIN() {
        clearPIN()
    }

    // MARK: - Persistence

    private func persistConsentFlag(autoUpdate: Bool) async {
        // Setup path: only Consent No uses this (autoUpdate false). Settings On uses confirmConsentOn.
        _ = autoUpdate
        do {
            var state = try await persistence.loadState()
            let updated = LedgerFacade.applyConsentDeclined(to: accounts)
            accounts = updated
            state.accounts = updated
            try await persistence.saveState(state)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistConsentAndBalance(paisa: Paisa, autoUpdate: Bool, isTyped: Bool) async {
        let source: LedgerFacade.BalanceSource = isTyped ? .typedManual : .snapshotFetch
        do {
            var state = try await persistence.loadState()
            let updated = LedgerFacade.applySetupOpeningBalance(
                to: accounts,
                balancePaisa: paisa,
                consentAutoUpdate: autoUpdate,
                source: source
            )
            accounts = updated
            state.accounts = updated
            try await persistence.saveState(state)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
