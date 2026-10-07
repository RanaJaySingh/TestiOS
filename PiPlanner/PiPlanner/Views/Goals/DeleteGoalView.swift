import SwiftUI

/// Delete goal flow — design frames 17 / 17a–17e (PRD R13 / R14, Spec BR-9 / §4.2 J3).
/// Visual: PiSheet chrome, PiCard release amount + destination split, destructive confirm CTA.
/// Prefer `DeleteGoalFlow(goal:…)` / this view from Goal detail Delete.
struct DeleteGoalView: View {
    @StateObject private var viewModel: DeleteGoalViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DeleteGoalViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience entry used by Goal detail / `DeleteGoalFlow`.
    init(
        goal: Goal,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        onDeleted: (() -> Void)? = nil
    ) {
        self.init(
            viewModel: DeleteGoalViewModel(
                goal: goal,
                goals: goals,
                persistence: persistence,
                formatting: formatting,
                onDeleted: onDeleted
            )
        )
    }

    var body: some View {
        PiSheet(
            title: "Delete goal",
            helper: viewModel.phase == .onlyGoalGate
                ? DeleteGoalService.onlyGoalGateMessage
                : DeleteGoalService.reassignCaption
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    headerTitle
                    releasedCard
                    if viewModel.phase == .onlyGoalGate {
                        onlyGoalGate
                    } else {
                        reassignmentSection
                        statusFooter
                        actionButtons
                    }
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PiColors.backgroundApp)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PiColors.backgroundApp, for: .navigationBar)
        .accessibilityIdentifier("goals.delete")
        .confirmationDialog(
            "Delete \(viewModel.deletingGoal.name)?",
            isPresented: $viewModel.showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Delete and move money", role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "\(viewModel.formattedReleasedAmount) moves to remaining goals. A History “deleted / moved” entry is written and standing split renormalises."
            )
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            NavigationStack {
                createReplacementForm
            }
        }
        .onChange(of: viewModel.didDelete) { deleted in
            if deleted { dismiss() }
        }
        .alert(
            "Couldn’t delete goal",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.showCreateSheet },
                set: { if !$0 { /* cleared on next edit */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var headerTitle: some View {
        Text("Delete \(viewModel.deletingGoal.name)")
            .font(PiTypography.body())
            .fontWeight(.semibold)
            .foregroundStyle(PiColors.destructive)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("goals.delete.header")
    }

    private var releasedCard: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Saved to reassign")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedReleasedAmount)
                    .font(PiTypography.amountHero())
                    .foregroundStyle(PiColors.navyPrimary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.delete.released")
    }

    private var onlyGoalGate: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
            Text(viewModel.statusMessage)
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("goals.delete.onlyGate")

            PrimaryCTA(
                title: "Create replacement goal",
                accessibilityIdentifier: "goals.delete.createReplacement"
            ) {
                viewModel.openCreateReplacement()
            }

            destructiveCTA(
                title: "Confirm delete",
                isEnabled: false,
                accessibilityIdentifier: "goals.delete.confirm"
            ) {}
        }
    }

    private var reassignmentSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            HStack {
                Text("Move to")
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.canStartEdit {
                    Button("Edit") {
                        viewModel.beginEdit()
                    }
                    .font(PiTypography.body())
                    .foregroundStyle(PiColors.navyPrimary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goals.delete.edit")
                } else if viewModel.isEditing {
                    Button("Done") {
                        viewModel.finishEdit()
                    }
                    .font(PiTypography.body())
                    .foregroundStyle(PiColors.navyPrimary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goals.delete.editDone")
                }
            }

            ForEach(viewModel.remainingGoals) { goal in
                goalRow(goal)
            }

            SecondaryCTA(
                title: "Add another goal",
                style: .text,
                accessibilityIdentifier: "goals.delete.addGoal"
            ) {
                viewModel.openCreateReplacement()
            }
        }
        .accessibilityIdentifier("goals.delete.reassign")
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack {
                    Text(goal.name)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                    Spacer()
                    Text(viewModel.formattedAmount(for: goal.id))
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.navyPrimary)
                        .monospacedDigit()
                }

                if viewModel.remainingGoals.count == 1 {
                    Text("100%")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                } else if viewModel.isEditing {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.displayPercents[goal.id] ?? 0) },
                                set: { viewModel.setDisplayPercent(goalID: goal.id, percent: Int($0.rounded())) }
                            ),
                            in: 0...100,
                            step: 1
                        )
                        .tint(PiColors.navyPrimary)
                        .accessibilityIdentifier("goals.delete.slider.\(goal.id.uuidString)")
                        Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                            .font(PiTypography.body())
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                } else {
                    Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(
                viewModel.canConfirm ? Color.secondary : PiColors.behind
            )
            .accessibilityIdentifier("goals.delete.status")
    }

    private var actionButtons: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            destructiveCTA(
                title: viewModel.isConfirming ? "Deleting…" : "Confirm delete",
                isEnabled: viewModel.canConfirm,
                accessibilityIdentifier: "goals.delete.confirm"
            ) {
                viewModel.requestConfirm()
            }
        }
    }

    /// Destructive filled CTA matching PrimaryCTA geometry (navy PrimaryCTA is for non-destructive actions).
    private func destructiveCTA(
        title: String,
        isEnabled: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
                .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.85))
                .background(PiColors.destructive.opacity(isEnabled ? 1 : 0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var createReplacementForm: some View {
        Form {
            Section("New goal") {
                TextField("Name", text: $viewModel.replacementName)
                    .accessibilityIdentifier("goals.delete.replacement.name")
                HStack {
                    Text("₹")
                    TextField("Target", text: $viewModel.replacementTargetRupees)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("goals.delete.replacement.target")
                }
            }
            if let message = viewModel.errorMessage {
                Section {
                    Text(message)
                        .foregroundStyle(PiColors.destructive)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Create goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { viewModel.showCreateSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task { await viewModel.createReplacementGoal() }
                }
                .accessibilityIdentifier("goals.delete.replacement.add")
            }
        }
    }
}

/// Entry point for Delete from Goal detail (PIP-49) or other callers.
struct DeleteGoalFlow: View {
    let goal: Goal
    let goals: [Goal]
    let persistence: any PersistenceServicing
    var formatting: any FormattingServicing = FormattingService()
    var onDeleted: (() -> Void)? = nil

    var body: some View {
        DeleteGoalView(
            goal: goal,
            goals: goals,
            persistence: persistence,
            formatting: formatting,
            onDeleted: onDeleted
        )
    }
}
