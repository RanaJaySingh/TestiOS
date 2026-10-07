import SwiftUI

/// Standing split screen — design frame 15 (PRD R12, Spec BR-2 / BR-4).
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
        .navigationTitle("Standing split")
        .navigationBarTitleDisplayMode(.inline)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                goalsSection
                statusFooter
                saveButton
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var oneGoalSkipContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(StandingSplitService.savedMoneyStaysPutMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("standingSplit.savedMoneyStaysPut")

            if let goal = viewModel.goals.first {
                Text(goal.name)
                    .font(.headline)
                Text("100%")
                    .font(.title3)
                    .fontWeight(.medium)
                    .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
            }

            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isSaving {
                ProgressView()
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("standingSplit.oneGoalSkip")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default split for new credits")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(StandingSplitService.savedMoneyStaysPutMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("standingSplit.savedMoneyStaysPut")
            Text("Every new credit uses these shares until you change them. Splits must total 100%.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(goal.name)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Text("Share")
                    .font(.subheadline)
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
                .font(.title3)
                .frame(width: 64)
                .accessibilityLabel("\(goal.name) percentage")
                .accessibilityHint("Enter a whole percent so all goals total 100")
                .accessibilityIdentifier("standingSplit.percent.\(goal.id.uuidString)")
                Text("%")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.callout)
            .foregroundStyle(viewModel.isValidTotal ? .secondary : .orange)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("standingSplit.status")
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave)
        .accessibilityLabel("Save standing split")
        .accessibilityHint(
            viewModel.canSave
                ? "Saves default shares for the next credit"
                : "Enabled when percentages total 100 percent"
        )
        .accessibilityIdentifier("standingSplit.save")
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
}

/// In-memory persistence for SwiftUI previews only.
private actor StandingSplitPreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
