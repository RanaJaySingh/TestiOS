import SwiftUI

/// In-Goals navigation targets — Goal detail (PIP-49); Transfer (PIP-55).
enum GoalsRoute: Hashable {
    case detail(UUID)
    case transfer
}

/// Goals tab shell — frames 9 / 9b / 9c (PIP-45); Pi* visuals (PIP-81); Sync/Update via ledger (PIP-102).
struct GoalsTabView: View {
    @ObservedObject var viewModel: GoalsViewModel
    /// Settings → Reset demo → Welcome (PIP-61 / PRD R17).
    var onDemoReset: (() -> Void)?
    /// Quick action → History tab (existing shell destination).
    var onOpenHistory: (() -> Void)?

    @State private var showNewGoalSheet = false
    /// Present Standing split after New goal sheet dismisses (PIP-105; avoid dual sheets).
    @State private var pendingStandingAfterNewGoal = false
    @StateObject private var newGoalHost = GoalChatViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                Text(viewModel.personaGreeting)
                    .font(PiTypography.title())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("goals.personaGreeting")

                if let banner = viewModel.openEntryBannerMessage {
                    OpenEntryBanner(message: banner) {
                        viewModel.assignOpenEntryNow()
                    }
                    .accessibilityIdentifier("goals.openEntryBanner")
                }

                BalanceCard(
                    formattedTotal: viewModel.formattedTotalSavings,
                    accountSubtitle: viewModel.dedicatedAccountSubtitle,
                    lastActivityLine: lastActivityLine,
                    actionTitle: viewModel.balanceActionTitle,
                    actionEnabled: viewModel.canTapBalanceAction,
                    onAction: { viewModel.tapBalanceAction() }
                )
                .accessibilityIdentifier("goals.balanceCard")

                QuickActionRow(
                    balanceActionTitle: GoalsTabService.quickBalanceActionTitle(for: viewModel.balanceAction),
                    balanceActionEnabled: viewModel.canTapBalanceAction,
                    onBalanceAction: { viewModel.tapBalanceAction() },
                    onNewGoal: { showNewGoalSheet = true },
                    onHistory: { onOpenHistory?() }
                ) {
                    NavigationLink(value: GoalsRoute.transfer) {
                        QuickActionCell(
                            title: "Transfer",
                            systemImage: PiIcons.transfer,
                            enabled: viewModel.goals.count >= 2,
                            accessibilityIdentifier: "goals.quickAction.transfer"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.goals.count < 2)
                    .accessibilityIdentifier("goals.transfer.entry")
                }

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("goals.info")
                }

                Button("Record a withdrawal") {
                    viewModel.openRecordWithdrawal()
                }
                .font(PiTypography.caption())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityIdentifier("goals.recordWithdrawal")

                goalsSection
            }
            .padding(DesignTokens.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                headerChromeIcon(systemName: PiIcons.headerSearch, label: "Search")
                headerChromeIcon(systemName: PiIcons.headerNotifications, label: "Notifications")
                headerChromeIcon(systemName: PiIcons.headerChart, label: "Chart")
                Button {
                    viewModel.openSettings()
                } label: {
                    Image(systemName: PiIcons.settings)
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("goals.settings")
            }
        }
        .navigationDestination(for: GoalsRoute.self) { route in
            switch route {
            case .detail(let goalID):
                if let goal = viewModel.goals.first(where: { $0.id == goalID }) {
                    GoalDetailView(
                        goal: goal,
                        formattedSaved: viewModel.formattedSavedAmount(for: goal),
                        statusLabel: viewModel.statusLabel(for: goal),
                        history: viewModel.history,
                        heldChanges: viewModel.heldGoalChanges,
                        standingSplits: viewModel.standingSplits,
                        allGoals: viewModel.goals,
                        persistence: viewModel.persistence
                    )
                } else {
                    GoalDetailView(
                        goal: nil,
                        formattedSaved: "—",
                        statusLabel: "—",
                        persistence: viewModel.persistence
                    )
                }
            case .transfer:
                TransferFlow(
                    goals: viewModel.goals,
                    standingSplits: viewModel.standingSplits,
                    persistence: viewModel.persistence,
                    formatting: viewModel.formatting,
                    onCompleted: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSyncSheet, onDismiss: {
            viewModel.sheetDismissed()
        }) {
            CreditSyncSheet(
                viewModel: viewModel.creditSyncViewModel,
                onOpenCreditEntry: { entry in
                    viewModel.presentCreditEntry(entry)
                },
                onWithdrawal: { presentation in
                    viewModel.handleWithdrawal(presentation)
                },
                onDismiss: { viewModel.showSyncSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showUpdateBalanceSheet, onDismiss: {
            viewModel.sheetDismissed()
        }) {
            CreditUpdateBalanceSheet(
                viewModel: viewModel.creditUpdateViewModel,
                onOpenCreditEntry: { entry in
                    viewModel.presentCreditEntry(entry)
                },
                onWithdrawal: { presentation in
                    viewModel.handleWithdrawal(presentation)
                },
                onRecordWithdrawal: {
                    viewModel.showUpdateBalanceSheet = false
                    viewModel.openRecordWithdrawal()
                },
                onDismiss: { viewModel.showUpdateBalanceSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showCreditEntry, onDismiss: {
            viewModel.creditEntryFinished()
        }) {
            NavigationStack {
                if let entry = viewModel.activeCreditEntry {
                    CreditEntryView(
                        viewModel: CreditEntryViewModel(
                            entry: entry,
                            goals: viewModel.goals,
                            persistence: viewModel.persistence,
                            formatting: viewModel.formatting
                        )
                    ) {
                        viewModel.showCreditEntry = false
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showRecordWithdrawal) {
            RecordWithdrawalSheet(
                previousBalance: viewModel.totalSavingsPaisa,
                goals: viewModel.goals,
                persistence: viewModel.persistence,
                formatting: viewModel.formatting,
                onContinue: { shortfall, newBalance in
                    viewModel.continueRecordWithdrawal(shortfall: shortfall, newBalance: newBalance)
                },
                onDismiss: { viewModel.showRecordWithdrawal = false }
            )
        }
        .sheet(isPresented: $viewModel.showWithdrawal, onDismiss: {
            viewModel.withdrawalFinished()
        }) {
            NavigationStack {
                if let shortfall = viewModel.activeWithdrawalShortfall,
                   let previous = viewModel.activeWithdrawalPrevious,
                   let newBalance = viewModel.activeWithdrawalNewBalance {
                    WithdrawalFlow(
                        shortfall: shortfall,
                        previousBalance: previous,
                        newBalance: newBalance,
                        goals: viewModel.goals,
                        persistence: viewModel.persistence,
                        formatting: viewModel.formatting,
                        ledger: viewModel.ledger,
                        isManualRecord: viewModel.activeWithdrawalIsManual
                    ) {
                        viewModel.showWithdrawal = false
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(
                goals: viewModel.goals,
                standingSplits: viewModel.standingSplits,
                persistence: viewModel.persistence,
                accounts: viewModel.accounts,
                onDemoReset: onDemoReset
            )
        }
        .sheet(isPresented: $showNewGoalSheet, onDismiss: {
            if pendingStandingAfterNewGoal {
                pendingStandingAfterNewGoal = false
                viewModel.presentStandingSplit()
            } else {
                Task { await viewModel.load() }
            }
        }) {
            NavigationStack {
                GoalFormView(
                    viewModel: newGoalHost,
                    mode: .create,
                    onCreateSave: { draft in
                        Task {
                            let presentStanding = await viewModel.createGoalFromForm(draft)
                            pendingStandingAfterNewGoal = presentStanding
                            showNewGoalSheet = false
                        }
                    }
                )
                .onAppear {
                    newGoalHost.reset()
                    newGoalHost.useFormPath()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showNewGoalSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showStandingSplit, onDismiss: {
            viewModel.standingSplitFinished()
        }) {
            NavigationStack {
                StandingSplitView(
                    viewModel: StandingSplitViewModel(
                        goals: viewModel.goals,
                        persistence: viewModel.persistence,
                        standingSplits: viewModel.standingSplits
                    ),
                    onDismiss: { viewModel.showStandingSplit = false }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { viewModel.showStandingSplit = false }
                    }
                }
            }
            .accessibilityIdentifier("goals.standingSplit.sheet")
        }
        .onChange(of: viewModel.showSettings) { isPresented in
            // Reload after Settings → Standing split save so shares stay current.
            if !isPresented {
                Task { await viewModel.load() }
            }
        }
        .task {
            await viewModel.load()
        }
        .onAppear {
            // Refresh cards after returning from Goal detail / edit (PIP-49).
            Task { await viewModel.load() }
        }
        .alert(
            "Something went wrong",
            isPresented: showErrorAlert
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .accessibilityIdentifier("goals.tab")
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }

    private var lastActivityLine: String {
        GoalsTabService.lastBalanceActivityLine(
            for: viewModel.balanceAction,
            referenceDate: GoalsTabService.lastBalanceActivityDate(history: viewModel.history)
        )
    }

    /// Chrome-only header icons (A2 / R20) — no new flows.
    private func headerChromeIcon(systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(PiColors.navyPrimary.opacity(0.85))
            .accessibilityLabel(label)
            .accessibilityIdentifier("goals.header.\(label.lowercased())")
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var goalsSection: some View {
        if viewModel.isLoading && !viewModel.hasGoals {
            ProgressView("Loading goals…")
                .frame(maxWidth: .infinity)
        } else if viewModel.hasGoals {
            Text("Your goals")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("goals.sectionHeader")

            ForEach(viewModel.goals) { goal in
                NavigationLink(value: GoalsRoute.detail(goal.id)) {
                    GoalCard(
                        name: goal.name,
                        formattedSavedOfTarget: GoalsTabService.savedOfTargetLabel(
                            savedPaisa: goal.savedAmount,
                            targetPaisa: goal.adjustedTarget,
                            formatting: viewModel.formatting
                        ),
                        statusLabel: viewModel.statusLabel(for: goal),
                        monthlyNeedLabel: GoalsTabService.monthlyNeedLabel(
                            monthlyNeedPaisa: goal.monthlyNeed,
                            formatting: viewModel.formatting
                        ),
                        creditsPercentLabel: GoalsTabService.creditsPercentLabel(
                            shareOfNewCredits: goal.shareOfNewCredits
                        )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goals.card.\(goal.id.uuidString)")
            }
        } else {
            Text("No goals yet")
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("goals.empty")
        }
    }
}
