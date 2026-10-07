import Combine
import Foundation

/// View model for Goals tab (frames 9 / 9b / 9c / 11) — PIP-45 / PIP-49 detail nav.
@MainActor
final class GoalsViewModel: ObservableObject {
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var heldGoalChanges: [HeldGoalChange] = []
    @Published private(set) var standingSplits: [StandingSplit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published var showSyncSheet = false
    @Published var showUpdateBalanceSheet = false
    @Published var showSettings = false
    /// Selected goal for navigation to GoalDetailView.
    @Published var selectedGoalID: UUID?

    /// Shared persistence for Goal detail / edit (PIP-49).
    let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let balanceSync: any BalanceSyncServicing

    init(
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(),
        initialState: PersistedAppState? = nil
    ) {
        self.persistence = persistence
        self.formatting = formatting
        self.balanceSync = balanceSync
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

    /// Consent On → present Sync sheet / run mock sync.
    func tapBalanceAction() {
        switch balanceAction {
        case .sync:
            showSyncSheet = true
        case .updateBalance:
            showUpdateBalanceSheet = true
        }
    }

    /// Invoked from SyncSheet — calls BalanceSyncService stub (full credit entry later).
    func performSync() async {
        guard let dedicated = AccountsService.dedicatedAccount(in: accounts) else {
            errorMessage = "No dedicated savings account."
            showSyncSheet = false
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        let result = await balanceSync.fetchBalance(accountId: dedicated.id)
        switch result {
        case .success(let paisa):
            await updateDedicatedBalance(paisa)
            showSyncSheet = false
        case .failure(let error):
            errorMessage = String(describing: error)
            showSyncSheet = false
        }
    }

    /// Invoked from UpdateBalanceSheet stub — applies typed amount without full credit flow.
    func applyManualBalance(_ paisa: Paisa) async {
        await updateDedicatedBalance(paisa)
        showUpdateBalanceSheet = false
    }

    private func updateDedicatedBalance(_ paisa: Paisa) async {
        do {
            var state = try await persistence.loadState()
            state.accounts = state.accounts.map { account in
                guard account.isDedicated else { return account }
                var updated = account
                updated.balance = paisa
                return updated
            }
            try await persistence.saveState(state)
            apply(state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ state: PersistedAppState) {
        accounts = state.accounts
        goals = state.goals
        history = state.history
        heldGoalChanges = state.heldGoalChanges
        standingSplits = state.standingSplits
    }
}
