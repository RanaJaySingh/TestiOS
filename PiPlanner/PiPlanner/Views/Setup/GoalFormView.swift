import SwiftUI

/// Goal form · create / edit — design frame 6 (PRD R5 / R9).
/// Visual parity (PIP-79): field stack, inflation row, live targets, valid/invalid chrome.
struct GoalFormView: View {
    @ObservedObject var viewModel: GoalChatViewModel
    var onSaved: (() -> Void)? = nil

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
                        action: { viewModel.cancelForm() }
                    )
                }
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
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
            Text("Define a goal")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
            Text("Name, target, dates, and share of new credits. Inflation defaults to 7%.")
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
            Text("Locked at ₹0 while creating a goal in setup.")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
            action: {
                if viewModel.saveForm() {
                    onSaved?()
                }
            }
        )
        .accessibilityLabel("Save goal")
        .accessibilityHint(
            isFormValid
                ? "Saves this goal"
                : "Disabled until name, target, and dates are valid"
        )
    }
}

#Preview {
    NavigationStack {
        GoalFormView(viewModel: GoalChatViewModel())
    }
}
