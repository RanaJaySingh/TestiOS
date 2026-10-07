import Combine
import Foundation

/// Sync sheet outcome after Continue (frames 10 / 10a / 10b).
enum CreditSyncSheetPhase: Equatable, Sendable {
    case idle
    case syncing
    case showingResult
}

/// View model for Credit sync (frames 10 / 10a / 10b) — PRD R7, R26; Spec BR-6.
/// Named to avoid colliding with PIP-45 stub `SyncSheet` / GoalsViewModel sync.
@MainActor
final class CreditSyncViewModel: ObservableObject {
    @Published private(set) var phase: CreditSyncSheetPhase = .idle
    @Published private(set) var previousBalance: Paisa = 0
    @Published private(set) var fetchedBalance: Paisa?
    @Published private(set) var infoMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var createdEntry: HistoryEntry?
    /// Full lower-balance context for Withdrawal sheet (PIP-107 / PIP-102).
    @Published private(set) var withdrawalPresentation: WithdrawalPresentation?
    @Published private(set) var isBlockedByOpenEntry = false

    /// Shortfall only — convenience for sheets / accessibility.
    var withdrawalShortfall: Paisa? { withdrawalPresentation?.shortfall }

    private let persistence: any PersistenceServicing
    private let balanceSync: any BalanceSyncServicing
    private let formatting: any FormattingServicing
    private let ledger: any LedgerEngine
    private let clock: () -> Date
    private let makeID: () -> UUID

    init(
        persistence: any PersistenceServicing,
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(
            fetchedBalancePaisa: MockBalanceSyncService.demoHigherBalancePaisa
        ),
        formatting: any FormattingServicing = FormattingService(),
        ledger: any LedgerEngine = StubLedgerEngine(),
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.persistence = persistence
        self.balanceSync = balanceSync
        self.formatting = formatting
        self.ledger = ledger
        self.clock = clock
        self.makeID = makeID
    }

    var formattedPrevious: String {
        formatting.formatINR(paisa: previousBalance)
    }

    var formattedFetched: String? {
        guard let fetchedBalance else { return nil }
        return formatting.formatINR(paisa: fetchedBalance)
    }

    var formattedNewAmount: String? {
        guard let fetchedBalance, fetchedBalance > previousBalance else { return nil }
        return formatting.formatINR(paisa: fetchedBalance - previousBalance)
    }

    var canContinueToCreditEntry: Bool {
        createdEntry != nil && !createdEntry!.isLocked
    }

    var compareResult: BalanceCompareResult? {
        guard let fetchedBalance else { return nil }
        return CreditEntryService.compare(
            previousBalance: previousBalance,
            newBalance: fetchedBalance
        )
    }

    func prepare(previousBalance: Paisa, history: [HistoryEntry]) {
        self.previousBalance = previousBalance
        isBlockedByOpenEntry = ledger.isSyncOrUpdateBlocked(history: history)
        fetchedBalance = nil
        infoMessage = nil
        errorMessage = nil
        createdEntry = nil
        withdrawalPresentation = nil
        phase = .idle
        if isBlockedByOpenEntry {
            infoMessage = "Assign the open credit before Sync."
        }
    }

    func loadAndPrepare() async {
        do {
            let state = try await persistence.loadState()
            let previous = AccountsService.dedicatedAccount(in: state.accounts)?.balance ?? 0
            prepare(previousBalance: previous, history: state.history)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches balance and processes higher / same / lower outcomes.
    func syncNow() async {
        guard !isBlockedByOpenEntry else {
            infoMessage = "Assign the open credit before Sync."
            return
        }
        phase = .syncing
        errorMessage = nil
        infoMessage = nil
        createdEntry = nil
        withdrawalPresentation = nil
        defer {
            if phase == .syncing { phase = .showingResult }
        }

        do {
            let state = try await persistence.loadState()
            guard let dedicated = AccountsService.dedicatedAccount(in: state.accounts) else {
                errorMessage = "No dedicated savings account."
                phase = .showingResult
                return
            }
            previousBalance = dedicated.balance

            let result = await balanceSync.fetchBalance(accountId: dedicated.id)
            switch result {
            case .failure(let syncError):
                errorMessage = String(describing: syncError)
                phase = .showingResult
            case .success(let fetched):
                fetchedBalance = fetched
                let outcome = try ledger.processBalanceUpdate(
                    state: state,
                    newBalance: fetched,
                    dedicatedAccountID: dedicated.id,
                    isTyped: false,
                    id: makeID(),
                    createdAt: clock()
                )
                switch outcome {
                case .noNewCredit(let message):
                    infoMessage = message
                    phase = .showingResult
                case .withdrawalRequired(let shortfall, let previous, let newBalance):
                    withdrawalPresentation = WithdrawalPresentation(
                        shortfall: shortfall,
                        previousBalance: previous,
                        newBalance: newBalance
                    )
                    infoMessage = "Balance went down by \(formatting.formatINR(paisa: shortfall))."
                    phase = .showingResult
                case .openCreditCreated(let next, let entry):
                    try await persistence.saveState(next)
                    createdEntry = entry
                    phase = .showingResult
                }
            }
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            phase = .showingResult
        } catch {
            errorMessage = error.localizedDescription
            phase = .showingResult
        }
    }
}
