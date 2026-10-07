import SwiftUI

/// Opening split screen — design frames 8 (multi-goal) and one-goal skip (PIP-101).
/// Visual parity (PIP-79): goal rows, %, Lock this split PrimaryCTA (≠100% vs 100%).
/// One goal → 100% default, skip split editor, auto-lock Opening History + standing split.
struct OpeningSplitView: View {
    @ObservedObject var viewModel: OpeningSplitViewModel
    var onNavigateToGoals: () -> Void

    var body: some View {
        Group {
            if viewModel.isReadOnly || viewModel.shouldPresentEditor {
                multiGoalContent
            } else {
                oneGoalSkipContent
            }
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle(viewModel.shouldPresentEditor || viewModel.isReadOnly ? "Opening split" : "Opening balance")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .confirmationDialog(
            "Lock this split?",
            isPresented: $viewModel.showConfirmLock,
            titleVisibility: .visible
        ) {
            Button("Lock this split") {
                Task { await viewModel.confirmLock() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Locked amounts never change. This creates your Opening balance History entry.")
        }
        .task {
            if !viewModel.shouldPresentEditor && !viewModel.isReadOnly {
                await viewModel.applySingleGoalSkipIfNeeded()
            }
        }
        .onChange(of: viewModel.shouldNavigateToGoals) { shouldNavigate in
            if shouldNavigate {
                onNavigateToGoals()
            }
        }
        .alert(
            "Couldn’t lock split",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { /* read-only clear via next edit */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .accessibilityIdentifier("openingSplit.view")
    }

    // MARK: - Multi-goal / read-only

    private var multiGoalContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                header
                balanceCard
                goalsSection
                statusFooter
                if !viewModel.isReadOnly {
                    lockButton
                }
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One-goal skip: no % editor — auto-lock 100% and continue to Goals.
    private var oneGoalSkipContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
            Text("One goal — 100% assigned")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.statusMessage)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let goal = viewModel.goals.first {
                PiCard(padding: DesignTokens.Space.s16) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                        Text(goal.name)
                            .font(PiTypography.body())
                            .fontWeight(.semibold)
                        Text(viewModel.formattedOpeningBalance)
                            .font(PiTypography.amountHero())
                            .foregroundStyle(PiColors.navyPrimary)
                            .monospacedDigit()
                        Text("100%")
                            .font(PiTypography.title())
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(PiColors.navyPrimary)
                            .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
                    }
                }
            }

            if viewModel.isLocking || !viewModel.didAutoSkip {
                ProgressView("Locking opening balance…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
            }

            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("openingSplit.oneGoalSkip")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text(viewModel.isReadOnly ? "Opening balance" : "Assign your opening balance")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
            Text(
                viewModel.isReadOnly
                    ? OpeningSplitService.lockedAmountsCaption
                    : "Every rupee goes to a goal. Splits must total 100%."
            )
            .font(PiTypography.body())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var balanceCard: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
                Text("Opening balance")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedOpeningBalance)
                    .font(PiTypography.amountHero())
                    .foregroundStyle(PiColors.navyPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Opening balance \(viewModel.formattedOpeningBalance)")
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                HStack {
                    Text(goal.name)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(viewModel.formattedAmount(for: goal.id))
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityLabel("Amount \(viewModel.formattedAmount(for: goal.id))")
                }

                if viewModel.isReadOnly {
                    Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                        .font(PiTypography.title())
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .accessibilityLabel(
                            "\(goal.name) \(viewModel.displayPercents[goal.id] ?? 0) percent, locked"
                        )
                } else {
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
                        .monospacedDigit()
                        .frame(width: 64)
                        .accessibilityLabel("\(goal.name) percentage")
                        .accessibilityHint("Enter a whole percent so all goals total 100")
                        Text("%")
                            .font(PiTypography.title())
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.body())
            .foregroundStyle(
                viewModel.canLock || viewModel.isReadOnly
                    ? Color.secondary
                    : PiColors.behind
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var lockButton: some View {
        Group {
            if viewModel.isLocking {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
            } else {
                PrimaryCTA(
                    title: "Lock this split",
                    isEnabled: viewModel.canLock,
                    accessibilityIdentifier: "openingSplit.lockCTA",
                    action: { viewModel.requestLock() }
                )
                .accessibilityLabel("Lock this split")
                .accessibilityHint(
                    viewModel.canLock
                        ? "Locks opening amounts and creates History entry"
                        : "Enabled when percentages total 100 percent"
                )
            }
        }
    }
}

#Preview("Multi-goal") {
    NavigationStack {
        OpeningSplitView(
            viewModel: OpeningSplitViewModel(
                goals: [
                    Goal(
                        id: UUID(),
                        name: "Car",
                        targetAmount: 50_000_000,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86_400 * 365),
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: 0,
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
                        savedAmount: 0,
                        shareOfNewCredits: Decimal(string: "0.4")!,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ],
                openingBalance: 10_000_000,
                persistence: PreviewPersistence()
            ),
            onNavigateToGoals: {}
        )
    }
}

#Preview("One-goal skip") {
    NavigationStack {
        OpeningSplitView(
            viewModel: OpeningSplitViewModel(
                goals: [
                    Goal(
                        id: UUID(),
                        name: "Emergency Fund",
                        targetAmount: 20_000_000,
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86_400 * 365),
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: 0,
                        shareOfNewCredits: Decimal(string: "1.0")!,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                ],
                openingBalance: 10_000_000,
                persistence: PreviewPersistence()
            ),
            onNavigateToGoals: {}
        )
    }
}

/// In-memory persistence for SwiftUI previews only.
private actor PreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
