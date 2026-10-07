import SwiftUI

/// Withdrawal flow — design frames 18 / 18a / 18b / 18c (PRD R15, Spec BR-8).
struct WithdrawalView: View {
    @StateObject private var viewModel: WithdrawalViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: WithdrawalViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience entry used by Goals tab (Sync lower / Record a withdrawal).
    init(
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        isManualRecord: Bool = false,
        onSaved: (() -> Void)? = nil
    ) {
        self.init(
            viewModel: WithdrawalViewModel(
                shortfall: shortfall,
                previousBalance: previousBalance,
                newBalance: newBalance,
                goals: goals,
                persistence: persistence,
                formatting: formatting,
                isManualRecord: isManualRecord,
                onSaved: onSaved
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                balanceSummary
                reductionsSection
                statusFooter
                actionButtons
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Withdrawal")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.withdrawal")
        .onChange(of: viewModel.didSave) { saved in
            if saved { dismiss() }
        }
        .alert(
            "Couldn’t save withdrawal",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdrawal")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.caption)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("goals.withdrawal.header")
    }

    private var balanceSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledRow("Previous", viewModel.formattedPrevious)
            labeledRow("Now", viewModel.formattedNewBalance)
            labeledRow("Shortfall", viewModel.formattedShortfall)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.withdrawal.summary")
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private var reductionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reduce from")
                    .font(.headline)
                Spacer()
                if viewModel.canStartEdit {
                    Button("Edit") {
                        viewModel.beginEdit()
                    }
                    .accessibilityIdentifier("goals.withdrawal.edit")
                } else if viewModel.isEditing {
                    Button("Done") {
                        viewModel.finishEdit()
                    }
                    .accessibilityIdentifier("goals.withdrawal.editDone")
                }
            }

            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
        .accessibilityIdentifier("goals.withdrawal.reductions")
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                Text(viewModel.formattedReduction(for: goal.id, previewing: viewModel.isEditing))
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            Text(
                "Saved \(viewModel.formattedSaved(for: goal)) → \(viewModel.afterWithdrawalSaved(for: goal, previewing: viewModel.isEditing))"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if viewModel.isEditing {
                HStack {
                    Text("₹")
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.editRupeeDigits[goal.id] ?? "0" },
                            set: { viewModel.setEditRupeeDigits(goalID: goal.id, digits: $0) }
                        )
                    )
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("goals.withdrawal.amount.\(goal.id.uuidString)")
                }
                .font(.body)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.subheadline)
            .foregroundStyle(
                viewModel.phase == .invalidTotal || viewModel.phase == .goalBelowZero
                    ? Color.red.opacity(0.9)
                    : Color.secondary
            )
            .accessibilityIdentifier("goals.withdrawal.status")
    }

    private var actionButtons: some View {
        Button {
            Task { await viewModel.saveAndLock() }
        } label: {
            Text(viewModel.isSaving ? "Saving…" : "Save and lock")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave)
        .accessibilityIdentifier("goals.withdrawal.save")
    }
}

/// Entry point for Withdrawal from Goals Sync lower / Record a withdrawal.
struct WithdrawalFlow: View {
    let shortfall: Paisa
    let previousBalance: Paisa
    let newBalance: Paisa
    let goals: [Goal]
    let persistence: any PersistenceServicing
    var formatting: any FormattingServicing = FormattingService()
    var isManualRecord: Bool = false
    var onSaved: (() -> Void)? = nil

    var body: some View {
        WithdrawalView(
            shortfall: shortfall,
            previousBalance: previousBalance,
            newBalance: newBalance,
            goals: goals,
            persistence: persistence,
            formatting: formatting,
            isManualRecord: isManualRecord,
            onSaved: onSaved
        )
    }
}

/// Manual path (18c): enter shortfall amount, then open the same Withdrawal flow.
struct RecordWithdrawalSheet: View {
    let previousBalance: Paisa
    let goals: [Goal]
    let persistence: any PersistenceServicing
    var formatting: any FormattingServicing = FormattingService()
    var onContinue: (_ shortfall: Paisa, _ newBalance: Paisa) -> Void
    var onDismiss: () -> Void

    @State private var rupeeDigits = ""

    private var shortfallPaisa: Paisa {
        (Paisa(rupeeDigits.filter(\.isNumber)) ?? 0) * 100
    }

    private var canContinue: Bool {
        shortfallPaisa > 0 && shortfallPaisa <= previousBalance
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Current: \(formatting.formatINR(paisa: previousBalance))")
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("₹")
                        TextField("Amount withdrawn", text: $rupeeDigits)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("goals.recordWithdrawal.digits")
                    }
                } footer: {
                    Text(WithdrawalService.manualRecordCaption)
                }

                if shortfallPaisa > previousBalance {
                    Section {
                        Text("Amount can’t exceed the current balance.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Record a withdrawal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onContinue(shortfallPaisa, previousBalance - shortfallPaisa)
                    }
                    .disabled(!canContinue)
                    .accessibilityIdentifier("goals.recordWithdrawal.continue")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("goals.recordWithdrawal")
    }
}
