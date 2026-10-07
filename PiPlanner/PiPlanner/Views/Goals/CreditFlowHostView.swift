import SwiftUI

/// Host surface Goals (PIP-45) can embed for Sync / Update / Credit entry / open-entry banner.
/// Keeps PIP-47 additive so GoalsTabView layout from PIP-45 need not be rewritten.
struct CreditFlowHostView: View {
    let persistence: any PersistenceServicing
    var balanceSync: any BalanceSyncServicing = MockBalanceSyncService(
        fetchedBalancePaisa: MockBalanceSyncService.demoHigherBalancePaisa
    )
    var formatting: any FormattingServicing = FormattingService()
    /// Consent On → Sync; Consent Off → Update balance.
    var prefersSync: Bool = true
    /// Called when lower balance is detected (host may present Withdrawal).
    var onWithdrawalRequested: (WithdrawalPresentation) -> Void = { _ in }

    @StateObject private var syncViewModel: CreditSyncViewModel
    @StateObject private var updateViewModel: CreditUpdateBalanceViewModel
    @State private var openEntry: HistoryEntry?
    @State private var creditEntryViewModel: CreditEntryViewModel?
    @State private var showSyncSheet = false
    @State private var showUpdateSheet = false
    @State private var showCreditEntry = false
    @State private var showWithdrawal = false
    @State private var withdrawalShortfall: Paisa?
    @State private var withdrawalPrevious: Paisa?
    @State private var withdrawalNewBalance: Paisa?
    @State private var withdrawalGoals: [Goal] = []
    @State private var bannerMessage: String?
    @State private var syncBlocked = false

    init(
        persistence: any PersistenceServicing,
        balanceSync: any BalanceSyncServicing = MockBalanceSyncService(
            fetchedBalancePaisa: MockBalanceSyncService.demoHigherBalancePaisa
        ),
        formatting: any FormattingServicing = FormattingService(),
        prefersSync: Bool = true,
        onWithdrawalRequested: @escaping (WithdrawalPresentation) -> Void = { _ in }
    ) {
        self.persistence = persistence
        self.balanceSync = balanceSync
        self.formatting = formatting
        self.prefersSync = prefersSync
        self.onWithdrawalRequested = onWithdrawalRequested
        _syncViewModel = StateObject(
            wrappedValue: CreditSyncViewModel(
                persistence: persistence,
                balanceSync: balanceSync,
                formatting: formatting
            )
        )
        _updateViewModel = StateObject(
            wrappedValue: CreditUpdateBalanceViewModel(
                persistence: persistence,
                balanceSync: balanceSync,
                formatting: formatting
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let bannerMessage {
                OpenEntryBanner(message: bannerMessage) {
                    if let openEntry {
                        presentCreditEntry(openEntry)
                    }
                }
            }

            Button(prefersSync ? "Sync" : "Update balance") {
                if syncBlocked {
                    return
                }
                if prefersSync {
                    showSyncSheet = true
                } else {
                    showUpdateSheet = true
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(syncBlocked)
            .accessibilityIdentifier(prefersSync ? "creditHost.sync" : "creditHost.update")

            Text("PIP-47 credit flow host — Goals tab can present these sheets.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task { await refreshBanner() }
        .sheet(isPresented: $showSyncSheet) {
            CreditSyncSheet(
                viewModel: syncViewModel,
                onOpenCreditEntry: { entry in
                    showSyncSheet = false
                    presentCreditEntry(entry)
                },
                onWithdrawal: { presentation in
                    showSyncSheet = false
                    handleWithdrawal(presentation)
                },
                onDismiss: { showSyncSheet = false }
            )
        }
        .sheet(isPresented: $showUpdateSheet) {
            CreditUpdateBalanceSheet(
                viewModel: updateViewModel,
                onOpenCreditEntry: { entry in
                    showUpdateSheet = false
                    presentCreditEntry(entry)
                },
                onWithdrawal: { presentation in
                    showUpdateSheet = false
                    handleWithdrawal(presentation)
                },
                onDismiss: { showUpdateSheet = false }
            )
        }
        .sheet(isPresented: $showCreditEntry) {
            NavigationStack {
                if let creditEntryViewModel {
                    CreditEntryView(viewModel: creditEntryViewModel) {
                        showCreditEntry = false
                        Task { await refreshBanner() }
                    }
                }
            }
        }
        .sheet(isPresented: $showWithdrawal) {
            NavigationStack {
                if let shortfall = withdrawalShortfall,
                   let previous = withdrawalPrevious,
                   let newBalance = withdrawalNewBalance {
                    WithdrawalFlow(
                        shortfall: shortfall,
                        previousBalance: previous,
                        newBalance: newBalance,
                        goals: withdrawalGoals,
                        persistence: persistence,
                        formatting: formatting
                    ) {
                        showWithdrawal = false
                        Task { await refreshBanner() }
                    }
                }
            }
        }
    }

    private func presentCreditEntry(_ entry: HistoryEntry) {
        Task {
            do {
                let state = try await persistence.loadState()
                let vm = CreditEntryViewModel(
                    entry: entry,
                    goals: state.goals,
                    persistence: persistence,
                    formatting: formatting
                )
                await MainActor.run {
                    creditEntryViewModel = vm
                    openEntry = entry
                    showCreditEntry = true
                }
                await refreshBanner()
            } catch {
                // Banner refresh will still reflect persisted open entry if any.
                await refreshBanner()
            }
        }
    }

    private func handleWithdrawal(_ presentation: WithdrawalPresentation) {
        Task {
            do {
                let state = try await persistence.loadState()
                await MainActor.run {
                    withdrawalShortfall = presentation.shortfall
                    withdrawalPrevious = presentation.previousBalance
                    withdrawalNewBalance = presentation.newBalance
                    withdrawalGoals = state.goals
                    showWithdrawal = true
                    onWithdrawalRequested(presentation)
                }
            } catch {
                await MainActor.run {
                    onWithdrawalRequested(presentation)
                }
            }
        }
    }

    private func refreshBanner() async {
        do {
            let state = try await persistence.loadState()
            if let entry = CreditEntryService.openCreditEntry(in: state.history) {
                openEntry = entry
                bannerMessage = CreditEntryService.openEntryBannerMessage(
                    for: entry,
                    formatting: formatting
                )
                syncBlocked = true
            } else {
                openEntry = nil
                bannerMessage = nil
                syncBlocked = false
            }
        } catch {
            bannerMessage = nil
            syncBlocked = false
        }
    }
}
