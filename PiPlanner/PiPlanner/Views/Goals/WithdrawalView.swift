import SwiftUI

/// Withdrawal flow — design frames 18 / 18a / 18b / 18c (PRD R14 / R15, Spec BR-8 / §4.2 J5).
/// Visual: PiSheet chrome, PiCard summary/rows, negative-amount treatment, PrimaryCTA Save and lock.
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
        ledger: any LedgerEngine = StubLedgerEngine(),
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
                ledger: ledger,
                isManualRecord: isManualRecord,
                onSaved: onSaved
            )
        )
    }

    var body: some View {
        PiSheet(
            title: "Withdrawal",
            helper: viewModel.caption
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    balanceSummary
                    reductionsSection
                    statusFooter
                    actionButtons
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PiColors.backgroundApp)
            .accessibilityIdentifier("goals.withdrawal.header")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PiColors.backgroundApp, for: .navigationBar)
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

    private var balanceSummary: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                labeledRow("Previous", viewModel.formattedPrevious)
                labeledRow("Now", viewModel.formattedNewBalance)
                labeledRow("Shortfall", viewModel.formattedShortfall, emphasizeNegative: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.withdrawal.summary")
    }

    private func labeledRow(_ title: String, _ value: String, emphasizeNegative: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
            Spacer()
            Text(emphasizeNegative ? Self.asNegativeAmount(value) : value)
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(emphasizeNegative ? PiColors.destructive : Color.primary)
                .monospacedDigit()
        }
    }

    private var reductionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            HStack {
                Text("Reduce from")
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
                    .accessibilityIdentifier("goals.withdrawal.edit")
                } else if viewModel.isEditing {
                    Button("Done") {
                        viewModel.finishEdit()
                    }
                    .font(PiTypography.body())
                    .foregroundStyle(PiColors.navyPrimary)
                    .buttonStyle(.plain)
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
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack {
                    Text(goal.name)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                    Spacer()
                    Text(
                        Self.asNegativeAmount(
                            viewModel.formattedReduction(for: goal.id, previewing: viewModel.isEditing)
                        )
                    )
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(PiColors.destructive)
                    .monospacedDigit()
                }

                Text(
                    "Saved \(viewModel.formattedSaved(for: goal)) → \(viewModel.afterWithdrawalSaved(for: goal, previewing: viewModel.isEditing))"
                )
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)

                if viewModel.isEditing {
                    HStack {
                        Text("₹")
                            .foregroundStyle(PiColors.navyPrimary)
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
                    .font(PiTypography.body())
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(
                viewModel.phase == .invalidTotal || viewModel.phase == .goalBelowZero
                    ? PiColors.destructive
                    : Color.secondary
            )
            .accessibilityIdentifier("goals.withdrawal.status")
    }

    private var actionButtons: some View {
        PrimaryCTA(
            title: viewModel.isSaving ? "Saving…" : "Save and lock",
            isEnabled: viewModel.canSave,
            accessibilityIdentifier: "goals.withdrawal.save"
        ) {
            Task { await viewModel.saveAndLock() }
        }
    }

    /// Design frames 18 / 18a — reductions shown as −₹ amounts (visual only; VM stays positive).
    private static func asNegativeAmount(_ formatted: String) -> String {
        if formatted.hasPrefix("-") || formatted.hasPrefix("−") {
            return formatted.replacingOccurrences(of: "-", with: "−")
        }
        if formatted == "₹0" || formatted == "0" {
            return formatted
        }
        return "−\(formatted)"
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
    var ledger: any LedgerEngine = StubLedgerEngine()
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
            ledger: ledger,
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
            PiSheet(
                title: "Record a withdrawal",
                helper: WithdrawalService.manualRecordCaption
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    PiCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                            Text("Current: \(formatting.formatINR(paisa: previousBalance))")
                                .font(PiTypography.caption())
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("₹")
                                    .font(PiTypography.title())
                                    .foregroundStyle(PiColors.navyPrimary)
                                TextField("Amount withdrawn", text: $rupeeDigits)
                                    .keyboardType(.numberPad)
                                    .font(PiTypography.amountHero())
                                    .foregroundStyle(PiColors.navyPrimary)
                                    .accessibilityIdentifier("goals.recordWithdrawal.digits")
                            }
                        }
                    }

                    if shortfallPaisa > previousBalance {
                        Text("Amount can’t exceed the current balance.")
                            .font(PiTypography.caption())
                            .foregroundStyle(PiColors.destructive)
                    }

                    PrimaryCTA(
                        title: "Continue",
                        isEnabled: canContinue,
                        accessibilityIdentifier: "goals.recordWithdrawal.continue"
                    ) {
                        onContinue(shortfallPaisa, previousBalance - shortfallPaisa)
                    }

                    SecondaryCTA(title: "Cancel", style: .text, action: onDismiss)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .background(PiColors.backgroundApp)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("goals.recordWithdrawal")
    }
}
