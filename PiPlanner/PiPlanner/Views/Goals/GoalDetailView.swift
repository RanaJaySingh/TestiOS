import SwiftUI

/// Goal detail — design frame 14 (PRD R13 / R10 / R11).
/// Visual parity via DesignTokens / Components / PiIcons. Init matches PIP-45 call site.
/// PIP-105: Edit → Goal form; held via `LedgerEngineCore.updateGoalPending`.
struct GoalDetailView: View {
    @StateObject private var viewModel: GoalDetailViewModel
    @StateObject private var editFormHost = GoalChatViewModel()
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
        allGoals: [Goal] = [],
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
                allGoals: allGoals,
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
            allGoals: goals,
            persistence: persistence,
            formatting: formatting
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                if viewModel.hasHeldChange {
                    heldBanner
                }
                VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                    heroSection
                    metricsSection
                }
                .accessibilityIdentifier("goals.detail.metrics")
                actionsRow
                fromHistorySection
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .accessibilityIdentifier("goals.detail")
        .navigationDestination(for: GoalDetailRoute.self) { route in
            switch route {
            case .edit:
                if let goal = viewModel.goal {
                    GoalDetailHeldEditForm(
                        goal: goal,
                        formHost: editFormHost,
                        onSave: { draft in
                            await viewModel.saveHeldEdit(formDraft: draft)
                        }
                    )
                } else {
                    Text("Goal not found.")
                        .foregroundStyle(.secondary)
                }
            case .transfer:
                // PIP-55: real Transfer flow. Keep GoalDetailView otherwise unchanged.
                if let persistence {
                    let goals = viewModel.allGoals.isEmpty
                        ? (viewModel.goal.map { [$0] } ?? [])
                        : viewModel.allGoals
                    TransferFlow(
                        goals: goals,
                        standingSplits: viewModel.standingSplits,
                        persistence: persistence,
                        formatting: formatting,
                        prefill: TransferService.Prefill(
                            fromGoalId: viewModel.goal?.id,
                            toGoalId: nil,
                            amountPaisa: nil
                        ),
                        onCompleted: {
                            Task { await viewModel.refresh() }
                        }
                    )
                } else {
                    Text("Transfer requires persistence.")
                        .foregroundStyle(.secondary)
                        .padding()
                        .accessibilityIdentifier("goals.transfer.unavailable")
                }
            case .delete:
                // PIP-53: real Delete flow. Keep GoalDetailView otherwise unchanged.
                if let goal = viewModel.goal, let persistence {
                    DeleteGoalFlow(
                        goal: goal,
                        goals: viewModel.allGoals.isEmpty ? [goal] : viewModel.allGoals,
                        persistence: persistence,
                        formatting: formatting,
                        onDeleted: {
                            Task { await viewModel.refresh() }
                        }
                    )
                } else {
                    Text("Delete requires a saved goal and persistence.")
                        .foregroundStyle(.secondary)
                        .padding()
                        .accessibilityIdentifier("goals.delete.unavailable")
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                toastBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(DesignTokens.Space.s16)
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

    // MARK: - Held info (13g)

    private var heldBanner: some View {
        Text(viewModel.heldInfoMessage)
            .font(PiTypography.body())
            .foregroundStyle(PiColors.chipLightBlueLabel)
            .padding(DesignTokens.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PiColors.chipLightBlue.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .accessibilityIdentifier("goals.detail.heldInfo")
            .accessibilityLabel(viewModel.heldInfoMessage)
    }

    // MARK: - Hero (large saved + status)

    private var heroSection: some View {
        PiCard(padding: DesignTokens.Space.s20) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("Saved")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                Text(viewModel.formattedSaved)
                    .font(PiTypography.amountHero())
                    .monospacedDigit()
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityLabel("Saved \(viewModel.formattedSaved)")

                statusChip
            }
        }
    }

    private var statusChip: some View {
        Text(viewModel.statusLabel)
            .font(PiTypography.caption())
            .fontWeight(.semibold)
            .foregroundStyle(statusForeground)
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(statusForeground.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            .accessibilityLabel("Status \(viewModel.statusLabel)")
            .accessibilityIdentifier(statusAccessibilityID)
    }

    private var statusForeground: Color {
        switch viewModel.statusLabel {
        case "On track":
            return PiColors.positiveGreen
        case "Behind":
            return PiColors.behind
        default:
            return .secondary
        }
    }

    private var statusAccessibilityID: String {
        switch viewModel.statusLabel {
        case "On track":
            return "goals.detail.status.onTrack"
        case "Behind":
            return "goals.detail.status.behind"
        default:
            return "goals.detail.status"
        }
    }

    // MARK: - Metrics (adjusted target, % reached, monthly need, dates, inflation, share)

    private var metricsSection: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                metricRow(title: "Target", value: viewModel.formattedTarget)
                metricRow(title: "Adjusted target", value: viewModel.formattedAdjustedTarget)
                metricRow(title: "% reached", value: percentReachedLabel)
                metricRow(title: "Monthly need", value: viewModel.formattedMonthlyNeed)

                Divider()
                    .padding(.vertical, DesignTokens.Space.s8)

                VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                    metricRow(title: "Start", value: viewModel.startDateLabel)
                    metricRow(title: "End", value: viewModel.endDateLabel)
                }
                .accessibilityIdentifier("goals.detail.dates")

                Divider()
                    .padding(.vertical, DesignTokens.Space.s8)

                metricRow(title: "Inflation", value: viewModel.inflationLabel)
                metricRow(title: "Share of new credits", value: viewModel.shareLabel)
            }
        }
    }

    /// Presentation-only % of adjusted target reached (saved ÷ adjusted). No ViewModel change.
    private var percentReachedLabel: String {
        guard let goal = viewModel.goal, goal.adjustedTarget > 0 else { return "—" }
        let fraction = Decimal(goal.savedAmount) / Decimal(goal.adjustedTarget)
        let percent = GoalValidationService.displayPercent(fromFraction: fraction)
        return "\(percent)%"
    }

    // MARK: - Actions (Transfer / Edit / Delete)

    private var actionsRow: some View {
        HStack(spacing: DesignTokens.Space.s12) {
            NavigationLink(value: GoalDetailRoute.transfer) {
                actionLabel(
                    title: "Transfer",
                    systemImage: PiIcons.transfer,
                    emphasis: .secondary
                )
            }
            .accessibilityIdentifier("goals.detail.transfer")

            NavigationLink(value: GoalDetailRoute.edit) {
                actionLabel(
                    title: "Edit",
                    systemImage: "pencil",
                    emphasis: .secondary
                )
            }
            .accessibilityIdentifier("goals.detail.edit")
            .disabled(viewModel.goal == nil)

            NavigationLink(value: GoalDetailRoute.delete) {
                actionLabel(
                    title: "Delete",
                    systemImage: "trash",
                    emphasis: .destructive
                )
            }
            .accessibilityIdentifier("goals.detail.delete")
        }
    }

    private enum ActionEmphasis {
        case secondary
        case destructive
    }

    private func actionLabel(
        title: String,
        systemImage: String,
        emphasis: ActionEmphasis
    ) -> some View {
        let foreground: Color = {
            switch emphasis {
            case .secondary:
                return PiColors.navyPrimary
            case .destructive:
                return PiColors.destructive
            }
        }()

        return VStack(spacing: DesignTokens.Space.s8) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(PiTypography.caption())
                .fontWeight(.semibold)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Space.s12)
        .background(PiColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                .strokeBorder(foreground.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(
            color: Color.black.opacity(0.04),
            radius: 4,
            x: 0,
            y: 2
        )
    }

    // MARK: - From History

    private var fromHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("From History")
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityAddTraits(.isHeader)

            if viewModel.relatedHistory.isEmpty {
                PiCard {
                    Text("No history for this goal yet.")
                        .font(PiTypography.body())
                        .foregroundStyle(.secondary)
                }
            } else {
                PiCard(padding: DesignTokens.Space.s12) {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.relatedHistory.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider()
                                    .padding(.vertical, DesignTokens.Space.s8)
                            }
                            historyRow(entry)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("goals.detail.history")
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.s12) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack(spacing: DesignTokens.Space.s8) {
                    Text(viewModel.historyTitle(for: entry))
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if entry.isLocked {
                        Image(systemName: PiIcons.lock)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Locked")
                    }
                }
                Text(viewModel.historyDateLabel(for: entry))
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignTokens.Space.s8)
            Text(viewModel.historyAmountLabel(for: entry))
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(PiColors.navyPrimary)
        }
        .padding(.vertical, DesignTokens.Space.s8)
        .accessibilityElement(children: .combine)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
            Spacer(minLength: DesignTokens.Space.s12)
            Text(value)
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var toastBanner: some View {
        Text(viewModel.toastMessage)
            .font(PiTypography.body())
            .fontWeight(.semibold)
            .foregroundStyle(Color.white)
            .padding(.horizontal, DesignTokens.Space.s16)
            .padding(.vertical, DesignTokens.Space.s12)
            .background(PiColors.navyPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .accessibilityIdentifier("goals.detail.toast")
            .accessibilityLabel(viewModel.toastMessage)
    }
}

/// Goal detail → Goal form (held edit) destination (PIP-105).
private struct GoalDetailHeldEditForm: View {
    let goal: Goal
    @ObservedObject var formHost: GoalChatViewModel
    var onSave: (GoalFormDraft) async -> GoalEditCommitResult?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GoalFormView(
            viewModel: formHost,
            mode: .heldEdit,
            onSaved: { dismiss() },
            onHeldEditSave: { draft in
                Task {
                    if await onSave(draft) != nil {
                        dismiss()
                    }
                }
            }
        )
        .onAppear {
            formHost.reset()
            formHost.editDefinedGoal(goal)
        }
    }
}

#Preview("On track") {
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

#Preview("Behind") {
    NavigationStack {
        GoalDetailView(
            goal: DemoSeed.sampleGoals.count > 1 ? DemoSeed.sampleGoals[1] : DemoSeed.sampleGoals[0],
            formattedSaved: "₹40,000",
            statusLabel: "Behind",
            history: []
        )
    }
}
