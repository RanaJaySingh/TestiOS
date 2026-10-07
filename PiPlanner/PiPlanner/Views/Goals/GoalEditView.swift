import SwiftUI

/// Goal edit — design frame 6e (PRD R11 / R24, Spec BR-4 / PIP-97).
/// Saved amount is locked; save shows toast via detail and holds changes to next credit.
/// Uses DesignTokens / Pi* chrome from the visual wave (aligned with GoalFormView).
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
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
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
                        .font(PiTypography.caption())
                        .foregroundStyle(PiColors.behind)
                }
                saveButton
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Edit goal")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
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
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text(viewModel.goal.name)
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Edits apply at the next credit. Earlier history is unchanged.")
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Name")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                TextField("e.g. Car", text: $viewModel.draft.name)
                    .font(PiTypography.body())
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Goal name")
                    .accessibilityIdentifier("goals.edit.name")
            }
        }
    }

    private var targetField: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Target")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.s8 / 2) {
                    Text("₹")
                        .font(PiTypography.title())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.navyPrimary)
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.draft.targetRupeeDigits },
                            set: { viewModel.draft.targetRupeeDigits = $0.filter(\.isNumber) }
                        )
                    )
                    .keyboardType(.numberPad)
                    .font(PiTypography.title())
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityLabel("Target in rupees")
                    .accessibilityIdentifier("goals.edit.target")
                }
                Text(viewModel.formatINR(paisa: viewModel.draft.targetPaisa))
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var dateFields: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                DatePicker(
                    "Start",
                    selection: $viewModel.draft.startDate,
                    displayedComponents: .date
                )
                .tint(PiColors.navyPrimary)
                .accessibilityIdentifier("goals.edit.start")
                DatePicker(
                    "End",
                    selection: $viewModel.draft.endDate,
                    displayedComponents: .date
                )
                .tint(PiColors.navyPrimary)
                .accessibilityIdentifier("goals.edit.end")
            }
        }
    }

    private var inflationRow: some View {
        Button {
            viewModel.showInflationPopup = true
        } label: {
            PiCard(padding: DesignTokens.Space.s16) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
                        Text("Inflation")
                            .font(PiTypography.caption())
                            .foregroundStyle(.secondary)
                        Text("\(viewModel.draft.inflationPercentDisplay)%")
                            .font(PiTypography.body())
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(PiColors.navyPrimary)
                    }
                    Spacer()
                    Text("Edit")
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.navyPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inflation \(viewModel.draft.inflationPercentDisplay) percent")
        .accessibilityHint("Opens inflation popup")
        .accessibilityIdentifier("goals.edit.inflation")
    }

    private var shareField: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack {
                    Text("Share of new credits")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.draft.sharePercentDisplay)%")
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(PiColors.navyPrimary)
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
                .tint(PiColors.navyPrimary)
                .accessibilityLabel("Share of new credits")
                .accessibilityIdentifier("goals.edit.share")
            }
        }
    }

    private var lockedSavedRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
            Text("Saved so far")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            Text(viewModel.formatINR(paisa: viewModel.lockedSavedAmount))
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("Locked — transfers and credits change saved amount.")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goals.edit.savedLocked")
        .accessibilityLabel(
            "Saved so far \(viewModel.formatINR(paisa: viewModel.lockedSavedAmount)), locked"
        )
    }

    private var metrics: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                metricRow(
                    title: "Inflation-adjusted target",
                    value: viewModel.formatINR(paisa: viewModel.draft.adjustedTargetPaisa)
                )
                metricRow(
                    title: "Required savings / month",
                    value: viewModel.formatINR(paisa: viewModel.draft.monthlyNeedPaisa)
                )
            }
        }
    }

    private var heldHint: some View {
        Text(GoalHeldChangeService.toastMessage)
            .font(PiTypography.caption())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("goals.edit.heldHint")
            .accessibilityLabel(GoalHeldChangeService.toastMessage)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(PiColors.navyPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        PrimaryCTA(
            title: viewModel.isSaving ? "Saving…" : "Save",
            isEnabled: viewModel.canSave && !viewModel.isSaving,
            accessibilityIdentifier: "goals.edit.save"
        ) {
            Task {
                if let result = await viewModel.save() {
                    onSaved?(result)
                    dismiss()
                }
            }
        }
        .accessibilityLabel("Save goal edits")
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
