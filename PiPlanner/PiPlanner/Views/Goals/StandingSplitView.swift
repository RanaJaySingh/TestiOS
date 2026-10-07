import SwiftUI

/// Standing split screen — design frame 15 (PRD R12 / R14, Spec BR-2 / BR-4 / §4.2 J3).
/// Visual: PiSheet chrome, PiCard % rows, PrimaryCTA Save (disabled until 100%).
struct StandingSplitView: View {
    @ObservedObject var viewModel: StandingSplitViewModel
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if viewModel.shouldPresentEditor {
                multiGoalEditor
            } else {
                oneGoalSkipContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PiColors.backgroundApp, for: .navigationBar)
        .task {
            if !viewModel.shouldPresentEditor {
                await viewModel.applySingleGoalSkipIfNeeded()
            }
        }
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                onDismiss()
            }
        }
        .alert(
            "Couldn’t save standing split",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { /* cleared on next edit */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .accessibilityIdentifier("standingSplit.view")
    }

    private var multiGoalEditor: some View {
        PiSheet(
            title: "Standing split",
            helper: "Default split for new credits. Splits must total 100%."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    savedMoneyCaption
                    goalsSection
                    statusFooter
                    saveButton
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PiColors.backgroundApp)
        }
    }

    private var oneGoalSkipContent: some View {
        PiSheet(
            title: "Standing split",
            helper: StandingSplitService.savedMoneyStaysPutMessage
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                if let goal = viewModel.goals.first {
                    PiCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                            Text(goal.name)
                                .font(PiTypography.body())
                                .fontWeight(.semibold)
                            Text("100%")
                                .font(PiTypography.title())
                                .foregroundStyle(PiColors.navyPrimary)
                                .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
                        }
                    }
                }

                Text(viewModel.statusMessage)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if viewModel.isSaving {
                    ProgressView()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PiColors.backgroundApp)
            .accessibilityIdentifier("standingSplit.oneGoalSkip")
        }
    }

    private var savedMoneyCaption: some View {
        Text(StandingSplitService.savedMoneyStaysPutMessage)
            .font(PiTypography.body())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("standingSplit.savedMoneyStaysPut")
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text(goal.name)
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Text("Share")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField(
                        "%",
                        value: Binding(
                            get: { viewModel.displayPercents[goal.id] ?? 0 },
                            set: { viewModel.setDisplayPercent(goalID: goal.id, percent: $0) }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(PiTypography.title())
                    .foregroundStyle(PiColors.navyPrimary)
                    .frame(width: 64)
                    .accessibilityLabel("\(goal.name) percentage")
                    .accessibilityHint("Enter a whole percent so all goals total 100")
                    .accessibilityIdentifier("standingSplit.percent.\(goal.id.uuidString)")
                    Text("%")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(viewModel.isValidTotal ? Color.secondary : PiColors.behind)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("standingSplit.status")
    }

    private var saveButton: some View {
        PrimaryCTA(
            title: viewModel.isSaving ? "Saving…" : "Save",
            isEnabled: viewModel.canSave,
            accessibilityIdentifier: "standingSplit.save"
        ) {
            Task { await viewModel.save() }
        }
        .accessibilityLabel("Save standing split")
        .accessibilityHint(
            viewModel.canSave
                ? "Saves default shares for the next credit"
                : "Enabled when percentages total 100 percent"
        )
    }
}

#Preview("Multi-goal") {
    NavigationStack {
        StandingSplitView(
            viewModel: StandingSplitViewModel(
                goals: [
                    Goal(
                        id: UUID(),
                        name: "Car",
                        targetAmount: 50_000_000,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86_400 * 365),
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: 6_000_000,
                        shareOfNewCredits: Decimal(string: "0.6")!,
                        createdAt: Date(),
                        updatedAt: Date()
                    ),
                    Goal(
                        id: UUID(),
                        name: "Emergency Fund",
                        targetAmount: 20_000_000,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86_400 * 365),
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: 4_000_000,
                        shareOfNewCredits: Decimal(string: "0.4")!,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ],
                persistence: StandingSplitPreviewPersistence()
            ),
            onDismiss: {}
        )
    }
    .piPlannerTheme()
}

#Preview("One-goal skip") {
    NavigationStack {
        StandingSplitView(
            viewModel: StandingSplitViewModel(
                goals: [
                    Goal(
                        id: UUID(),
                        name: "Emergency Fund",
                        targetAmount: 20_000_000,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86_400 * 365),
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: 10_000_000,
                        shareOfNewCredits: Decimal(string: "1.0")!,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ],
                persistence: StandingSplitPreviewPersistence()
            ),
            onDismiss: {}
        )
    }
    .piPlannerTheme()
}

/// In-memory persistence for SwiftUI previews only.
private actor StandingSplitPreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
