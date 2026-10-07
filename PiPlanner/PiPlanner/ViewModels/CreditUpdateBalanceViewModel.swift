import Combine
import Foundation

enum CreditUpdatePath: Equatable, Sendable {
    case choice
    case manual
    case pin
    case otherApp
    case wrongPin
}

/// View model for Update balance (frames 11a–11c / typed 13t) — PRD R7; Spec BR-6; PIP-100 routes.
/// Named `CreditUpdateBalance*` to avoid colliding with PIP-45 `GoalsUpdateBalanceSheet`.
@MainActor
final class CreditUpdateBalanceViewModel: ObservableObject {
    @Published var path: CreditUpdatePath = .choice
    @Published var rupeeDigits = ""
    @Published var pinDigits = ""
    @Published private(set) var previousBalance: Paisa = 0
    @Published private(set) var isWorking = false
    @Published private(set) var infoMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var createdEntry: HistoryEntry?
    @Published private(set) var withdrawalShortfall: Paisa?
    @Published private(set) var isBlockedByOpenEntry = false
    @Published private(set) var pinError: PinError?
    @Published private(set) var dedicatedIsPaytmLinked = true
    @Published private(set) var dedicatedBankTitle: String?

    private let persistence: any PersistenceServicing
    private let balanceSync: any BalanceSyncServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID

    init(
        persistence: any PersistenceServicing,
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(
            fetchedBalancePaisa: MockBalanceSyncService.demoHigherBalancePaisa
        ),
        formatting: any FormattingServicing = FormattingService(),
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.persistence = persistence
        self.balanceSync = balanceSync
        self.formatting = formatting
        self.clock = clock
        self.makeID = makeID
    }

    var formattedPrevious: String {
        formatting.formatINR(paisa: previousBalance)
    }

    var typedPaisa: Paisa {
        ConsentService.paisa(fromRupeeDigits: rupeeDigits)
    }

    var canContinueManual: Bool {
        !isBlockedByOpenEntry && ConsentService.canContinueManual(amountPaisa: typedPaisa)
    }

    var canSubmitPIN: Bool {
        !isBlockedByOpenEntry && ConsentService.isCompletePIN(pinDigits) && !isWorking
    }

    func loadAndPrepare() async {
        do {
            let state = try await persistence.loadState()
            let dedicated = AccountsService.dedicatedAccount(in: state.accounts)
            previousBalance = dedicated?.balance ?? 0
            dedicatedIsPaytmLinked = dedicated?.isPaytmLinked ?? false
            dedicatedBankTitle = dedicated.map { AccountsService.displayTitle(for: $0) }
            isBlockedByOpenEntry = CreditEntryService.isSyncOrUpdateBlocked(history: state.history)
            if isBlockedByOpenEntry {
                infoMessage = "Assign the open credit before Update."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func chooseManual() {
        guard !isBlockedByOpenEntry else { return }
        path = .manual
        errorMessage = nil
    }

    /// Balance sync: Paytm-linked → UPI PIN mock; Other UPI app → Manual amount only (PIP-100).
    func chooseBalanceSync() {
        guard !isBlockedByOpenEntry else { return }
        switch UpdateBalanceRoutingService.route(
            after: .balanceSync,
            dedicatedIsPaytmLinked: dedicatedIsPaytmLinked
        ) {
        case .upiPinMock:
            path = .pin
            pinDigits = ""
            pinError = nil
            errorMessage = nil
        case .otherUPIApp:
            path = .otherApp
            errorMessage = nil
        default:
            path = .manual
            errorMessage = nil
        }
    }

    func continueFromOtherApp() {
        path = .manual
        errorMessage = nil
    }

    func backToChoice() {
        path = .choice
        pinDigits = ""
        pinError = nil
    }

    func retryPIN() {
        pinDigits = ""
        pinError = nil
        path = .pin
        errorMessage = nil
    }

    func enterManuallyAfterWrongPin() {
        pinDigits = ""
        pinError = nil
        path = .manual
        errorMessage = nil
    }

    /// Typed balance path (frame 11b → 13t). Same History shape as PIN; `isTyped = true`.
    func applyTypedBalance() async {
        guard canContinueManual else { return }
        await processNewBalance(typedPaisa, isTyped: true)
    }

    /// Demo UPI PIN path (frame 11c → 10 → 13). Same History shape as Manual; `isTyped = false`.
    func submitPIN() async {
        guard canSubmitPIN else { return }
        isWorking = true
        pinError = nil
        defer { isWorking = false }

        let result = await balanceSync.verifyUPIPin(pin: pinDigits)
        switch result {
        case .failure(let error):
            pinError = error
            if error == .wrongPin {
                pinDigits = ""
                path = .wrongPin
                errorMessage = "Incorrect PIN. Try again or enter the balance manually."
            }
        case .success(let fetched):
            await processNewBalance(fetched, isTyped: false)
        }
    }

    func appendPINDigit(_ digit: String) {
        guard pinDigits.count < 4, digit.count == 1, digit.first?.isNumber == true else { return }
        pinDigits.append(digit)
        pinError = nil
    }

    func deletePINDigit() {
        guard !pinDigits.isEmpty else { return }
        pinDigits.removeLast()
        pinError = nil
    }

    private func processNewBalance(_ newBalance: Paisa, isTyped: Bool) async {
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        createdEntry = nil
        withdrawalShortfall = nil
        defer { isWorking = false }

        do {
            let state = try await persistence.loadState()
            guard let dedicated = AccountsService.dedicatedAccount(in: state.accounts) else {
                errorMessage = "No dedicated savings account."
                return
            }
            previousBalance = dedicated.balance

            let outcome = try CreditEntryService.processFetchedBalance(
                state: state,
                fetchedBalance: newBalance,
                dedicatedAccountID: dedicated.id,
                isTyped: isTyped,
                id: makeID(),
                createdAt: clock()
            )
            switch outcome {
            case .noNewCredit(let message):
                infoMessage = message
            case .withdrawalRequired(let shortfall, _, _):
                withdrawalShortfall = shortfall
                infoMessage = "Balance went down by \(formatting.formatINR(paisa: shortfall))."
            case .openCreditCreated(let next, let entry):
                try await persistence.saveState(next)
                createdEntry = entry
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
