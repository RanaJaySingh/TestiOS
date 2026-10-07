import SwiftUI

/// In-Goals navigation targets — Goal detail (PIP-49).
enum GoalsRoute: Hashable {
    case detail(UUID)
}

/// Goals tab — design frames 9 / 9b / 9c (PIP-45); detail via PIP-49.
struct GoalsTabView: View {
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BalanceCard(
                    formattedTotal: viewModel.formattedTotalSavings,
                    accountSubtitle: viewModel.dedicatedAccountSubtitle,
                    actionTitle: viewModel.balanceActionTitle,
                    onAction: { viewModel.tapBalanceAction() }
                )
                .accessibilityIdentifier("goals.balanceCard")

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
        .sheet(isPresented: $viewModel.showSyncSheet) {
            SyncSheet(
                isSyncing: viewModel.isSyncing,
                onSync: {
                    Task { await viewModel.performSync() }
                },
                onDismiss: { viewModel.showSyncSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showUpdateBalanceSheet) {
            GoalsUpdateBalanceSheet(
                currentFormatted: viewModel.formattedTotalSavings,
                onApply: { paisa in
                    Task { await viewModel.applyManualBalance(paisa) }
                },
                onDismiss: { viewModel.showUpdateBalanceSheet = false }
            )
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
