import SwiftUI

/// Goal detail — design frame 14 (PRD R10 / R11).
/// Init matches PIP-45 call site: `GoalDetailView(goal:formattedSaved:statusLabel:)`.
struct GoalDetailView: View {
    @StateObject private var viewModel: GoalDetailViewModel
    private let persistence: (any PersistenceServicing)?
    private let formatting: any FormattingServicing

    /// PIP-45-compatible entry. Prefer passing `goal`; labels are fallbacks when goal is nil.
    init(
        goal: Goal?,
        formattedSaved: String = "—",
        statusLabel: String = "—",
        history: [HistoryEntry] = [],
        heldChanges: [HeldGoalChange] = [],
        standingSplits: [StandingSplit] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.persistence = persistence
        self.formatting = formatting
        _viewModel = StateObject(
            wrappedValue: GoalDetailViewModel(
                goal: goal,
                formattedSaved: formattedSaved,
                statusLabel: statusLabel,
                history: history,
                heldChanges: heldChanges,
                standingSplits: standingSplits,
                persistence: persistence,
                formatting: formatting
            )
        )
    }

    /// Convenience for callers that already have a goal id + loaded list.
    init(
        goalID: UUID,
        goals: [Goal],
        formattedSaved: String = "—",
        statusLabel: String = "—",
        history: [HistoryEntry] = [],
        heldChanges: [HeldGoalChange] = [],
        standingSplits: [StandingSplit] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.init(
            goal: goals.first { $0.id == goalID },
            formattedSaved: formattedSaved,
            statusLabel: statusLabel,
            history: history,
            heldChanges: heldChanges,
            standingSplits: standingSplits,
            persistence: persistence,
            formatting: formatting
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.hasHeldChange {
                    heldBanner
                }
                metricsSection
                datesSection
                actionsRow
                fromHistorySection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.detail")
        .navigationDestination(for: GoalDetailRoute.self) { route in
            switch route {
            case .edit:
                if let goal = viewModel.goal {
                    GoalEditView(
                        goal: goal,
                        history: viewModel.history,
                        heldChanges: viewModel.heldChanges,
                        standingSplits: viewModel.standingSplits,
                        persistence: persistence,
                        formatting: formatting,
                        onSaved: { result in
                            viewModel.applyEditResult(result)
                        }
                    )
                } else {
                    Text("Goal not found.")
                        .foregroundStyle(.secondary)
                }
            case .transfer:
                GoalTransferStubView(goalName: viewModel.navigationTitle)
            case .delete:
                GoalDeleteStubView(goalName: viewModel.navigationTitle)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                toastBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showToast)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.showToast) { isShowing in
            guard isShowing else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                viewModel.dismissToast()
            }
        }
    }

    private var heldBanner: some View {
        Text(viewModel.heldInfoMessage)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("goals.detail.heldInfo")
            .accessibilityLabel(viewModel.heldInfoMessage)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow(title: "Saved", value: viewModel.formattedSaved)
            metricRow(title: "Status", value: viewModel.statusLabel)
            metricRow(title: "Target", value: viewModel.formattedTarget)
            metricRow(title: "Adjusted target", value: viewModel.formattedAdjustedTarget)
            metricRow(title: "Monthly need", value: viewModel.formattedMonthlyNeed)
            metricRow(title: "Inflation", value: viewModel.inflationLabel)
            metricRow(title: "Share of new credits", value: viewModel.shareLabel)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("goals.detail.metrics")
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            metricRow(title: "Start", value: viewModel.startDateLabel)
            metricRow(title: "End", value: viewModel.endDateLabel)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("goals.detail.dates")
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            NavigationLink(value: GoalDetailRoute.transfer) {
                actionLabel("Transfer")
            }
            .accessibilityIdentifier("goals.detail.transfer")

            NavigationLink(value: GoalDetailRoute.edit) {
                actionLabel("Edit")
            }
            .accessibilityIdentifier("goals.detail.edit")
            .disabled(viewModel.goal == nil)

            NavigationLink(value: GoalDetailRoute.delete) {
                actionLabel("Delete")
            }
            .accessibilityIdentifier("goals.detail.delete")
        }
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var fromHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From History")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if viewModel.relatedHistory.isEmpty {
                Text("No history for this goal yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.relatedHistory) { entry in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.historyTitle(for: entry))
                                .font(.body)
                                .fontWeight(.semibold)
                            Text(viewModel.historyDateLabel(for: entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if entry.isLocked {
                                Text("Locked")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(viewModel.historyAmountLabel(for: entry))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("goals.detail.history")
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var toastBanner: some View {
        Text(viewModel.toastMessage)
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("goals.detail.toast")
            .accessibilityLabel(viewModel.toastMessage)
    }
}

/// Stub Transfer destination — full UI is a separate ticket.
struct GoalTransferStubView: View {
    let goalName: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Transfer")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Move saved money from \(goalName). Full Transfer UI arrives in a later ticket.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.transfer.stub")
    }
}

/// Stub Delete destination — full flow is a separate ticket.
struct GoalDeleteStubView: View {
    let goalName: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Delete goal")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Delete \(goalName) and reassign saved money. Full Delete flow arrives in a later ticket.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Delete")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.delete.stub")
    }
}

#Preview("Detail") {
    NavigationStack {
        GoalDetailView(
            goal: DemoSeed.sampleGoals[0],
            formattedSaved: "₹60,000",
            statusLabel: "On track",
            history: [
                HistoryEntry(
                    id: UUID(),
                    type: .openingBalance,
                    createdAt: Date(),
                    isLocked: true,
                    previousBalance: nil,
                    newBalance: 10_000_000,
                    creditAmount: 10_000_000,
                    isTyped: false,
                    fromGoalId: nil,
                    toGoalId: nil,
                    transferAmount: nil,
                    withdrawalAmount: nil,
                    deletedGoalName: nil,
                    releasedAmount: nil,
                    allocations: [
                        GoalAllocation(
                            goalId: DemoSeed.sampleGoals[0].id,
                            goalName: "Car",
                            amount: 6_000_000,
                            percentage: Decimal(string: "0.6")!
                        )
                    ]
                )
            ]
        )
    }
}
