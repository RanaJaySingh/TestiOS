import SwiftUI

/// Open / locked New credit History entry (frames 13 / 13a–13g / 13t) — PIP-85 visual parity.
///
/// Visual / layout / token / component only. Lock / assign behaviour stays in
/// `CreditEntryViewModel` / `CreditEntryService` (unchanged).
struct CreditEntryView: View {
    @ObservedObject var viewModel: CreditEntryViewModel
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                header
                amountCard
                alreadySavedBlock
                thisCreditBlock
                if !viewModel.isLocked && !viewModel.isSingleGoal {
                    standingCheckbox
                }
                if !viewModel.isLocked {
                    createGoalLink
                }
                statusFooter
                if !viewModel.isLocked {
                    saveButton
                } else {
                    PrimaryCTA(
                        title: "Done",
                        accessibilityIdentifier: "creditEntry.done",
                        action: onDone
                    )
                }
            }
            .padding(DesignTokens.Space.s16)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle(viewModel.isLocked ? "Credit locked" : "New credit")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .sheet(isPresented: $viewModel.showCreateGoalSheet) {
            createGoalSheet
        }
        .alert(
            "Couldn’t save",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .accessibilityIdentifier("creditEntry.root")
    }

    // MARK: - Header (Assign now / Saved and locked + badges)

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("New credit")
                .font(PiTypography.caption())
                .foregroundStyle(PiColors.navyPrimary.opacity(0.72))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: DesignTokens.Space.s8) {
                if viewModel.isLocked {
                    lockedStatusLabel
                } else {
                    assignNowStatusLabel
                }
                Spacer(minLength: DesignTokens.Space.s8)
                badges
            }

            Text(
                viewModel.isLocked
                    ? OpeningSplitService.lockedAmountsCaption
                    : CreditEntryService.lockedOnceCaption
            )
            .font(PiTypography.body())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    private var assignNowStatusLabel: some View {
        Text(CreditEntryService.assignNowTitle)
            .font(PiTypography.title())
            .foregroundStyle(PiColors.navyPrimary)
            .accessibilityIdentifier("creditEntry.assignNow")
    }

    private var lockedStatusLabel: some View {
        HStack(spacing: DesignTokens.Space.s8) {
            Image(systemName: PiIcons.lock)
                .font(.title3)
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityLabel("Locked")
                .accessibilityIdentifier("creditEntry.lockIcon")
            Text("Saved and locked")
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityIdentifier("creditEntry.savedAndLocked")
        }
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: DesignTokens.Space.s8) {
            if viewModel.showsTypedBadge {
                entryBadge(title: "Typed", accessibilityIdentifier: "creditEntry.typedBadge")
            }
            if viewModel.showsCustomBadge {
                entryBadge(title: "Custom", accessibilityIdentifier: "creditEntry.customBadge")
            }
        }
    }

    private func entryBadge(title: String, accessibilityIdentifier: String) -> some View {
        Text(title)
            .font(PiTypography.caption())
            .fontWeight(.semibold)
            .foregroundStyle(PiColors.chipLightBlueLabel)
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(PiColors.chipLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    // MARK: - Amount summary card

    private var amountCard: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                if !viewModel.isTyped, let previous = viewModel.formattedPrevious {
                    labeledRow("Previous", previous)
                }
                if !viewModel.isTyped, let now = viewModel.formattedNewBalance {
                    labeledRow("Balance now", now)
                }
                labeledRow("New amount", viewModel.formattedCreditAmount, emphasize: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creditEntry.amountCard")
    }

    private func labeledRow(_ title: String, _ value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(emphasize ? PiTypography.title() : PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(emphasize ? PiColors.navyPrimary : .primary)
                .monospacedDigit()
        }
    }

    // MARK: - Already saved block (unchanged totals)

    private var alreadySavedBlock: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("Already saved, not changing")
                    .font(PiTypography.caption())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("creditEntry.alreadySavedHeader")

                ForEach(viewModel.goals) { goal in
                    HStack {
                        Text(goal.name)
                            .font(PiTypography.body())
                            .fontWeight(.medium)
                        Spacer()
                        Text(viewModel.formattedSavedSoFar(for: goal))
                            .font(PiTypography.body())
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("creditEntry.alreadySavedBlock")
    }

    // MARK: - This-credit split block

    private var thisCreditBlock: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text("Split \(viewModel.formattedCreditAmount) · This credit only")
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("creditEntry.thisCreditHeader")

                    if !viewModel.isLocked {
                        Text("Update percentages for this amount")
                            .font(PiTypography.caption())
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(viewModel.goals) { goal in
                    thisCreditGoalRow(goal)
                }
            }
        }
        .accessibilityIdentifier("creditEntry.thisCreditBlock")
    }

    @ViewBuilder
    private func thisCreditGoalRow(_ goal: Goal) -> some View {
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

            if viewModel.isSingleGoal {
                Text("100%")
                    .font(PiTypography.title())
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
            } else if viewModel.isLocked {
                Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                    .font(PiTypography.title())
                    .foregroundStyle(PiColors.navyPrimary)
            } else {
                HStack {
                    Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                        .frame(width: 56, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.displayPercents[goal.id] ?? 0) },
                            set: { viewModel.setDisplayPercent(goalID: goal.id, percent: Int($0.rounded())) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .tint(PiColors.navyPrimary)
                    .accessibilityLabel("\(goal.name) percent")
                    .accessibilityIdentifier("creditEntry.percent.\(goal.id.uuidString)")
                }
            }
        }
        .padding(.vertical, DesignTokens.Space.s8)
        .accessibilityElement(children: .contain)
    }

    private var standingCheckbox: some View {
        Toggle(isOn: $viewModel.useThisSplitForStanding) {
            Text(CreditEntryService.useThisSplitCheckboxTitle)
                .font(PiTypography.body())
        }
        .tint(PiColors.navyPrimary)
        .accessibilityIdentifier("creditEntry.useStanding")
    }

    private var createGoalLink: some View {
        SecondaryCTA(
            title: "Create goal",
            style: .text,
            accessibilityIdentifier: "creditEntry.createGoal",
            action: { viewModel.openCreateGoal() }
        )
    }

    private var createGoalSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                    Text("Create goal")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Saved starts at ₹0. Goal totals update only when you Save and lock this credit.")
                        .font(PiTypography.body())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    PiCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                            TextField("Name", text: $viewModel.createGoalName)
                                .font(PiTypography.body())
                                .accessibilityIdentifier("creditEntry.createGoal.name")
                            TextField("Target (₹)", text: $viewModel.createGoalTargetRupees)
                                .font(PiTypography.body())
                                .keyboardType(.numberPad)
                                .accessibilityIdentifier("creditEntry.createGoal.target")
                        }
                    }

                    if viewModel.isCreatingGoal {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        PrimaryCTA(
                            title: "Add goal",
                            accessibilityIdentifier: "creditEntry.createGoal.save"
                        ) {
                            Task { await viewModel.createGoal() }
                        }
                    }
                }
                .padding(DesignTokens.Space.s16)
            }
            .background(PiColors.backgroundApp.ignoresSafeArea())
            .navigationTitle("Create goal")
            .navigationBarTitleDisplayMode(.inline)
            .piPlannerTheme()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { viewModel.showCreateGoalSheet = false }
                }
            }
        }
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("creditEntry.status")
    }

    private var saveButton: some View {
        Group {
            if viewModel.isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
                    .accessibilityIdentifier("creditEntry.save")
            } else {
                PrimaryCTA(
                    title: "Save and lock",
                    isEnabled: viewModel.canSave,
                    accessibilityIdentifier: "creditEntry.save"
                ) {
                    Task {
                        await viewModel.saveAndLock()
                        if viewModel.isLocked {
                            onDone()
                        }
                    }
                }
            }
        }
    }
}
