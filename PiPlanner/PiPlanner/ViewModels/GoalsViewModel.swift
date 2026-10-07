import Combine
import Foundation

/// View model for Goals tab (frames 9 / 9b / 9c / 11) — PIP-45 / PIP-49 detail nav + PIP-47 credit flow.
@MainActor
final class GoalsViewModel: ObservableObject {
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var heldGoalChanges: [HeldGoalChange] = []
    @Published private(set) var standingSplits: [StandingSplit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var infoMessage: String?
    @Published var showSyncSheet = false
    @Published var showUpdateBalanceSheet = false
    @Published var showSettings = false
    @Published var showCreditEntry = false
    /// Withdrawal sheet (PIP-57) from Sync lower or Record a withdrawal.
    @Published var showWithdrawal = false
    /// Manual shortfall entry before Withdrawal (frame 18c).
    @Published var showRecordWithdrawal = false
    /// Selected goal for navigation to GoalDetailView.
    @Published var selectedGoalID: UUID?
    /// Open New credit entry pending assignment (frame 9b).
    @Published private(set) var openEntry: HistoryEntry?
    @Published private(set) var openEntryBannerMessage: String?
    /// Entry presented in CreditEntryView after Sync/Update Continue or Assign now.
    @Published private(set) var activeCreditEntry: HistoryEntry?
    /// Active withdrawal context for WithdrawalView.
    @Published private(set) var activeWithdrawalShortfall: Paisa?
    @Published private(set) var activeWithdrawalPrevious: Paisa?
    @Published private(set) var activeWithdrawalNewBalance: Paisa?
    @Published private(set) var activeWithdrawalIsManual = false

    /// Shared persistence for Goal detail / edit (PIP-49), credit sheets (PIP-47), and Standing split (PIP-51).
    let persistence: any PersistenceServicing
    let formatting: any FormattingServicing
    let balanceSync: any BalanceSyncServicing
    /// Owned credit-flow sheets (PIP-47).
    let creditSyncViewModel: CreditSyncViewModel
    let creditUpdateViewModel: CreditUpdateBalanceViewModel

    init(
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(
            fetchedBalancePaisa: MockBalanceSyncService.demoHigherBalancePaisa
        ),
        initialState: PersistedAppState? = nil
    ) {
        self.persistence = persistence
        self.formatting = formatting
        self.balanceSync = balanceSync
        self.creditSyncViewModel = CreditSyncViewModel(
            persistence: persistence,
            balanceSync: balanceSync,
            formatting: formatting
        )
        self.creditUpdateViewModel = CreditUpdateBalanceViewModel(
            persistence: persistence,
            balanceSync: balanceSync,
            formatting: formatting
        )
        if let initialState {
            apply(initialState)
        }
    }

    var totalSavingsPaisa: Paisa {
        GoalsTabService.totalSavingsPaisa(accounts: accounts, goals: goals)
    }

    var formattedTotalSavings: String {
        formatting.formatINR(paisa: totalSavingsPaisa)
    }

    var balanceAction: GoalsBalanceAction {
        GoalsTabService.balanceAction(for: accounts)
    }

    var balanceActionTitle: String {
        GoalsTabService.balanceActionTitle(for: balanceAction)
    }

    var dedicatedAccountSubtitle: String? {
        GoalsTabService.dedicatedAccountSubtitle(accounts: accounts)
    }

    var hasGoals: Bool {
        GoalsTabService.hasGoals(goals)
    }

    var selectedGoal: Goal? {
        guard let selectedGoalID else { return nil }
        return goals.first { $0.id == selectedGoalID }
    }

    /// BR-6 / R9 — Sync / Update blocked while an open credit exists.
    var isSyncOrUpdateBlocked: Bool {
        CreditEntryService.isSyncOrUpdateBlocked(history: history)
    }

    var canTapBalanceAction: Bool {
        !isSyncOrUpdateBlocked
    }

    func formattedSavedAmount(for goal: Goal) -> String {
        formatting.formatINR(paisa: goal.savedAmount)
    }

    func statusLabel(for goal: Goal) -> String {
        GoalsTabService.statusLabel(for: goal.status)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let state = try await persistence.loadState()
            apply(state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Gear → Settings.
    func openSettings() {
        showSettings = true
    }

    /// Goal card tap → Goal detail.
    func selectGoal(_ goal: Goal) {
        selectedGoalID = goal.id
    }

    func clearSelectedGoal() {
        selectedGoalID = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func clearInfo() {
        infoMessage = nil
    }

    /// Consent On → CreditSyncSheet; Consent Off → CreditUpdateBalanceSheet.
    /// Blocked when open entry pending (BR-6).
    func tapBalanceAction() {
        guard canTapBalanceAction else {
            infoMessage = "Assign the open credit before Sync or Update."
            return
        }
        infoMessage = nil
        switch balanceAction {
        case .sync:
            showSyncSheet = true
        case .updateBalance:
            showUpdateBalanceSheet = true
        }
    }

    /// Banner "Assign now" → open CreditEntryView for the pending entry.
    func assignOpenEntryNow() {
        guard let openEntry else { return }
        presentCreditEntry(openEntry)
    }

    func presentCreditEntry(_ entry: HistoryEntry) {
        activeCreditEntry = entry
        showSyncSheet = false
        showUpdateBalanceSheet = false
        showCreditEntry = true
    }

    func creditEntryFinished() {
        showCreditEntry = false
        activeCreditEntry = nil
        Task { await load() }
    }

    /// Lower-balance path (10b) → Withdrawal (18) with proportional default.
    func handleWithdrawal(shortfall: Paisa) {
        showSyncSheet = false
        showUpdateBalanceSheet = false
        let previous = AccountsService.dedicatedAccount(in: accounts)?.balance
            ?? creditSyncViewModel.previousBalance
        presentWithdrawal(
            shortfall: shortfall,
            previousBalance: previous,
            newBalance: previous - shortfall,
            isManual: false
        )
    }

    /// Manual "Record a withdrawal" (18c).
    func openRecordWithdrawal() {
        guard hasGoals, totalSavingsPaisa > 0 else {
            infoMessage = "Nothing to withdraw yet."
            return
        }
        infoMessage = nil
        showRecordWithdrawal = true
    }

    func presentWithdrawal(
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        isManual: Bool
    ) {
        activeWithdrawalShortfall = shortfall
        activeWithdrawalPrevious = previousBalance
        activeWithdrawalNewBalance = newBalance
        activeWithdrawalIsManual = isManual
        showRecordWithdrawal = false
        showSyncSheet = false
        showUpdateBalanceSheet = false
        showWithdrawal = true
    }

    func continueRecordWithdrawal(shortfall: Paisa, newBalance: Paisa) {
        let previous = AccountsService.dedicatedAccount(in: accounts)?.balance ?? previousBalanceFallback
        presentWithdrawal(
            shortfall: shortfall,
            previousBalance: previous,
            newBalance: newBalance,
            isManual: true
        )
    }

    func withdrawalFinished() {
        showWithdrawal = false
        activeWithdrawalShortfall = nil
        activeWithdrawalPrevious = nil
        activeWithdrawalNewBalance = nil
        activeWithdrawalIsManual = false
        Task { await load() }
    }

    private var previousBalanceFallback: Paisa {
        AccountsService.dedicatedAccount(in: accounts)?.balance ?? 0
    }

    /// After Sync/Update sheet closes without navigating to credit entry.
    func sheetDismissed() {
        Task { await load() }
    }

    private func apply(_ state: PersistedAppState) {
        accounts = state.accounts
        goals = state.goals
        history = state.history
        heldGoalChanges = state.heldGoalChanges
        standingSplits = state.standingSplits
        if let entry = CreditEntryService.openCreditEntry(in: state.history) {
            openEntry = entry
            openEntryBannerMessage = CreditEntryService.openEntryBannerMessage(
                for: entry,
                formatting: formatting
            )
        } else {
            openEntry = nil
            openEntryBannerMessage = nil
        }
    }
}
