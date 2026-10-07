import SwiftUI

/// Goal form presentation mode — create (setup / New goal) vs held edit from Goal detail (PIP-105).
enum GoalFormMode: Equatable, Sendable {
    case create
    /// Edit from Goal detail — save holds changes until the next credit.
    case heldEdit
}

/// Goal form · create / edit — design frame 6 (PRD R5 / R9 / R11).
/// Visual parity (PIP-79): field stack, inflation row, live targets, valid/invalid chrome.
struct GoalFormView: View {
    @ObservedObject var viewModel: GoalChatViewModel
    var mode: GoalFormMode = .create
    var onSaved: (() -> Void)? = nil
    /// Held-edit path: parent persists via `LedgerEngineCore.updateGoalPending` (PIP-105).
    var onHeldEditSave: ((GoalFormDraft) -> Void)? = nil
    /// Create path that needs the draft (Goals → New goal → engine createGoal).
    var onCreateSave: ((GoalFormDraft) -> Void)? = nil

    private var isFormValid: Bool { viewModel.formDraft.canSave }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                header
                fieldStack
                inflationRow
                shareField
                savedRow
                metrics
                saveButton
                if viewModel.phase == .form {
                    SecondaryCTA(
                        title: "Cancel",
                        style: .text,
                        action: {
                            if mode == .heldEdit {
                                onSaved?()
                            } else {
                                viewModel.cancelForm()
                            }
                        }
                    )
                }
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle(mode == .heldEdit ? "Edit goal" : "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .accessibilityIdentifier(mode == .heldEdit ? "goals.edit.form" : "goalForm.view")
        .sheet(isPresented: $viewModel.showInflationPopup) {
            InflationPopup(
                inflationRate: Binding(
                    get: { viewModel.formDraft.inflationRate },
                    set: { viewModel.formDraft.inflationRate = $0 }
                ),
                targetPaisa: viewModel.formDraft.targetPaisa,
                startDate: viewModel.formDraft.startDate,
                endDate: viewModel.formDraft.endDate,
                onDone: { viewModel.showInflationPopup = false }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text(mode == .heldEdit ? (viewModel.formDraft.name.isEmpty ? "Edit goal" : viewModel.formDraft.name) : "Define a goal")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
            Text(
                mode == .heldEdit
                    ? "Edits apply at the next credit. Earlier history is unchanged."
                    : "Name, target, dates, and share of new credits. Inflation defaults to 7%."
            )
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Field stack with valid / invalid chrome (AC state).
    private var fieldStack: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                nameField
                targetField
                dateFields
                if !isFormValid {
                    Text("Enter a name, target above ₹0, and an end date after start.")
                        .font(PiTypography.caption())
                        .foregroundStyle(PiColors.behind)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Form incomplete")
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .strokeBorder(
                    isFormValid ? Color.clear : PiColors.behind.opacity(0.55),
                    lineWidth: isFormValid ? 0 : 1.5
                )
        )
        .accessibilityIdentifier(isFormValid ? "goalForm.valid" : "goalForm.invalid")
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Name")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            TextField("e.g. Car", text: $viewModel.formDraft.name)
                .font(PiTypography.body())
                .textInputAutocapitalization(.words)
                .padding(.horizontal, DesignTokens.Space.s12)
                .padding(.vertical, DesignTokens.Space.s8)
                .background(PiColors.backgroundApp)
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                )
                .accessibilityLabel("Goal name")
        }
    }

    private var targetField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Target")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(PiTypography.title())
                    .fontWeight(.semibold)
                    .foregroundStyle(PiColors.navyPrimary)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.formDraft.targetRupeeDigits },
                        set: { viewModel.formDraft.targetRupeeDigits = $0.filter(\.isNumber) }
                    )
                )
                .keyboardType(.numberPad)
                .font(PiTypography.title())
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityLabel("Target in rupees")
            }
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(PiColors.backgroundApp)
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
            )
            Text(viewModel.formatINR(paisa: viewModel.formDraft.targetPaisa))
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var dateFields: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            DatePicker(
                "Start",
                selection: $viewModel.formDraft.startDate,
                displayedComponents: .date
            )
            .font(PiTypography.body())
            .tint(PiColors.navyPrimary)
            DatePicker(
                "End",
                selection: $viewModel.formDraft.endDate,
                displayedComponents: .date
            )
            .font(PiTypography.body())
            .tint(PiColors.navyPrimary)
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
                        Text("\(viewModel.formDraft.inflationPercentDisplay)%")
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
        .accessibilityLabel("Inflation \(viewModel.formDraft.inflationPercentDisplay) percent")
        .accessibilityHint("Opens inflation popup")
    }

    private var shareField: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack {
                    Text("Share of new credits")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.formDraft.sharePercentDisplay)%")
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(PiColors.navyPrimary)
                }
                Slider(
                    value: Binding(
                        get: {
                            (viewModel.formDraft.shareOfNewCredits as NSDecimalNumber).doubleValue * 100
                        },
                        set: { viewModel.formDraft.shareOfNewCredits = Decimal($0) / 100 }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(PiColors.navyPrimary)
                .accessibilityLabel("Share of new credits")
            }
        }
    }

    private var savedRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
            Text("Saved so far")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            Text(viewModel.formatINR(paisa: viewModel.formDraft.savedAmount))
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(
                mode == .heldEdit
                    ? "Saved amount is locked. Edits apply at the next credit."
                    : "Locked at ₹0 while creating a goal in setup."
            )
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(mode == .heldEdit ? "goals.edit.savedLocked" : "goalForm.saved")
    }

    private var metrics: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                metricRow(
                    title: "Inflation-adjusted target",
                    value: viewModel.formatINR(paisa: viewModel.formDraft.adjustedTargetPaisa)
                )
                metricRow(
                    title: "Monthly need",
                    value: viewModel.formatINR(paisa: viewModel.formDraft.monthlyNeedPaisa)
                )
            }
        }
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
        }
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        PrimaryCTA(
            title: "Save",
            isEnabled: isFormValid,
            accessibilityIdentifier: mode == .heldEdit ? "goals.edit.save" : "goalForm.save",
            action: {
                guard viewModel.formDraft.canSave else { return }
                let draft = viewModel.formDraft
                switch mode {
                case .heldEdit:
                    onHeldEditSave?(draft)
                case .create:
                    if let onCreateSave {
                        onCreateSave(draft)
                    } else if viewModel.saveForm() {
                        onSaved?()
                    }
                }
            }
        )
        .accessibilityLabel("Save goal")
        .accessibilityHint(
            isFormValid
                ? (mode == .heldEdit
                    ? "Saves changes that apply at the next credit"
                    : "Saves this goal")
                : "Disabled until name, target, and dates are valid"
        )
    }
}

#Preview {
    NavigationStack {
        GoalFormView(viewModel: GoalChatViewModel())
    }
}
