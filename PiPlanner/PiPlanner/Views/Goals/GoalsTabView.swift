import SwiftUI

/// In-Goals navigation targets — Goal detail (PIP-49).
enum GoalsRoute: Hashable {
    case detail(UUID)
}

/// Goals tab — design frames 9 / 9b / 9c (PIP-45); detail via PIP-49; Sync/Update/Credit via PIP-47.
struct GoalsTabView: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let banner = viewModel.openEntryBannerMessage {
                    OpenEntryBanner(message: banner) {
                        viewModel.assignOpenEntryNow()
                    }
                    .accessibilityIdentifier("goals.openEntryBanner")
                }

                BalanceCard(
                    formattedTotal: viewModel.formattedTotalSavings,
                    accountSubtitle: viewModel.dedicatedAccountSubtitle,
                    actionTitle: viewModel.balanceActionTitle,
                    actionEnabled: viewModel.canTapBalanceAction,
                    onAction: { viewModel.tapBalanceAction() }
                )
                .accessibilityIdentifier("goals.balanceCard")

                if let withdrawal = viewModel.withdrawalStubMessage {
                    Text(withdrawal)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("goals.withdrawalStub")
                }

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("goals.info")
                }

                goalsSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.openSettings()
                } label: {
                    Image(systemName: "gearshape")
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
                onWithdrawal: { shortfall in
                    viewModel.handleWithdrawalStub(shortfall: shortfall)
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
                onWithdrawal: { shortfall in
                    viewModel.handleWithdrawalStub(shortfall: shortfall)
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
        .sheet(isPresented: $viewModel.showSettings) {
            NavigationStack {
                SettingsView()
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

    @ViewBuilder
    private var goalsSection: some View {
        if viewModel.isLoading && !viewModel.hasGoals {
            ProgressView("Loading goals…")
                .frame(maxWidth: .infinity)
        } else if viewModel.hasGoals {
            Text("Your goals")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("goals.sectionHeader")

            ForEach(viewModel.goals) { goal in
                NavigationLink(value: GoalsRoute.detail(goal.id)) {
                    GoalCard(
                        name: goal.name,
                        formattedSaved: viewModel.formattedSavedAmount(for: goal),
                        statusLabel: viewModel.statusLabel(for: goal)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goals.card.\(goal.id.uuidString)")
            }
        } else {
            Text("No goals yet")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("goals.empty")
        }
    }
}
