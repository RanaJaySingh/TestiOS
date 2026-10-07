import SwiftUI

/// Delete goal flow — design frames 17 / 17a–17e (PRD R13, Spec BR-9).
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                releasedCard
                if viewModel.phase == .onlyGoalGate {
                    onlyGoalGate
                } else {
                    reassignmentSection
                    statusFooter
                    actionButtons
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Delete goal")
        .navigationBarTitleDisplayMode(.inline)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete \(viewModel.deletingGoal.name)")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(
                viewModel.phase == .onlyGoalGate
                    ? DeleteGoalService.onlyGoalGateMessage
                    : DeleteGoalService.reassignCaption
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("goals.delete.header")
    }

    private var releasedCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved to reassign")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.formattedReleasedAmount)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.delete.released")
    }

    private var onlyGoalGate: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("goals.delete.onlyGate")

            Button("Create replacement goal") {
                viewModel.openCreateReplacement()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("goals.delete.createReplacement")

            Button("Confirm delete") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .accessibilityIdentifier("goals.delete.confirm")
        }
    }

    private var reassignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Move to")
                    .font(.headline)
                Spacer()
                if viewModel.canStartEdit {
                    Button("Edit") {
                        viewModel.beginEdit()
                    }
                    .accessibilityIdentifier("goals.delete.edit")
                } else if viewModel.isEditing {
                    Button("Done") {
                        viewModel.finishEdit()
                    }
                    .accessibilityIdentifier("goals.delete.editDone")
                }
            }

            ForEach(viewModel.remainingGoals) { goal in
                goalRow(goal)
            }

            Button("Add another goal") {
                viewModel.openCreateReplacement()
            }
            .font(.subheadline)
            .accessibilityIdentifier("goals.delete.addGoal")
        }
        .accessibilityIdentifier("goals.delete.reassign")
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                Text(viewModel.formattedAmount(for: goal.id))
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if viewModel.remainingGoals.count == 1 {
                Text("100%")
                    .font(.title3)
                    .fontWeight(.medium)
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
                    .accessibilityIdentifier("goals.delete.slider.\(goal.id.uuidString)")
                    Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                        .font(.body)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            } else {
                Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                    .font(.title3)
                    .fontWeight(.medium)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("goals.delete.status")
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.requestConfirm()
            } label: {
                Text(viewModel.isConfirming ? "Deleting…" : "Confirm delete")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canConfirm)
            .accessibilityIdentifier("goals.delete.confirm")
        }
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
                        .foregroundStyle(.red)
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
