import SwiftUI

/// Goal edit — design frame 6e (PRD R11 / R24, Spec BR-4).
/// Saved amount is locked; save shows toast via detail and holds changes to next credit.
struct GoalEditView: View {
    @StateObject private var viewModel: GoalEditViewModel
    @Environment(\.dismiss) private var dismiss
    var onSaved: ((GoalEditCommitResult) -> Void)?

    init(
        goal: Goal,
        history: [HistoryEntry] = [],
        heldChanges: [HeldGoalChange] = [],
        standingSplits: [StandingSplit] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService(),
        onSaved: ((GoalEditCommitResult) -> Void)? = nil
    ) {
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: GoalEditViewModel(
                goal: goal,
                history: history,
                heldChanges: heldChanges,
                standingSplits: standingSplits,
                persistence: persistence,
                formatting: formatting
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                nameField
                targetField
                dateFields
                inflationRow
                shareField
                lockedSavedRow
                metrics
                heldHint
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                saveButton
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Edit goal")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.edit")
        .sheet(isPresented: $viewModel.showInflationPopup) {
            InflationPopup(
                inflationRate: Binding(
                    get: { viewModel.draft.inflationRate },
                    set: { viewModel.draft.inflationRate = $0 }
                ),
                targetPaisa: viewModel.draft.targetPaisa,
                startDate: viewModel.draft.startDate,
                endDate: viewModel.draft.endDate,
                onDone: { viewModel.showInflationPopup = false }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.goal.name)
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Edits apply at the next credit. Earlier history is unchanged.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("e.g. Car", text: $viewModel.draft.name)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Goal name")
                .accessibilityIdentifier("goals.edit.name")
        }
    }

    private var targetField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.title3)
                    .fontWeight(.semibold)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.draft.targetRupeeDigits },
                        set: { viewModel.draft.targetRupeeDigits = $0.filter(\.isNumber) }
                    )
                )
                .keyboardType(.numberPad)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityLabel("Target in rupees")
                .accessibilityIdentifier("goals.edit.target")
            }
            Text(viewModel.formatINR(paisa: viewModel.draft.targetPaisa))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var dateFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "Start",
                selection: $viewModel.draft.startDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("goals.edit.start")
            DatePicker(
                "End",
                selection: $viewModel.draft.endDate,
                displayedComponents: .date
            )
            .accessibilityIdentifier("goals.edit.end")
        }
    }

    private var inflationRow: some View {
        Button {
            viewModel.showInflationPopup = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inflation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.draft.inflationPercentDisplay)%")
                        .font(.body)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                Spacer()
                Text("Edit")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inflation \(viewModel.draft.inflationPercentDisplay) percent")
        .accessibilityIdentifier("goals.edit.inflation")
    }

    private var shareField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Share of new credits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.draft.sharePercentDisplay)%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: {
                        (viewModel.draft.shareOfNewCredits as NSDecimalNumber).doubleValue * 100
                    },
                    set: { viewModel.draft.shareOfNewCredits = Decimal($0) / 100 }
                ),
                in: 0...100,
                step: 1
            )
            .accessibilityLabel("Share of new credits")
            .accessibilityIdentifier("goals.edit.share")
        }
    }

    private var lockedSavedRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved so far")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.formatINR(paisa: viewModel.lockedSavedAmount))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("Locked — transfers and credits change saved amount.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.edit.savedLocked")
        .accessibilityLabel(
            "Saved so far \(viewModel.formatINR(paisa: viewModel.lockedSavedAmount)), locked"
        )
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricRow(
                title: "Inflation-adjusted target",
                value: viewModel.formatINR(paisa: viewModel.draft.adjustedTargetPaisa)
            )
            metricRow(
                title: "Monthly need",
                value: viewModel.formatINR(paisa: viewModel.draft.monthlyNeedPaisa)
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var heldHint: some View {
        Text(GoalHeldChangeService.toastMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("goals.edit.heldHint")
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
        }
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button {
            Task {
                if let result = await viewModel.save() {
                    onSaved?(result)
                    dismiss()
                }
            }
        } label: {
            Text(viewModel.isSaving ? "Saving…" : "Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave)
        .accessibilityLabel("Save goal edits")
        .accessibilityIdentifier("goals.edit.save")
        .accessibilityHint(
            viewModel.canSave
                ? "Saves changes for the next credit"
                : "Disabled until name, target, and dates are valid"
        )
    }
}

#Preview {
    NavigationStack {
        GoalEditView(goal: DemoSeed.sampleGoals[0])
    }
}
