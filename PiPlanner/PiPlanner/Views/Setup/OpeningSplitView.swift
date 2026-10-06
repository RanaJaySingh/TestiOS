import SwiftUI

/// Opening split screen — design frames 8 (multi-goal) and 8b (single-goal).
struct OpeningSplitView: View {
    @ObservedObject var viewModel: OpeningSplitViewModel
    var onNavigateToGoals: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                balanceCard
                goalsSection
                statusFooter
                if !viewModel.isReadOnly {
                    lockButton
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Opening split")
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.isReadOnly ? "Opening balance" : "Assign your opening balance")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(
                viewModel.isReadOnly
                    ? OpeningSplitService.lockedAmountsCaption
                    : "Every rupee goes to a goal. Splits must total 100%."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Opening balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.formattedOpeningBalance)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Opening balance \(viewModel.formattedOpeningBalance)")
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(viewModel.formattedAmount(for: goal.id))
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .accessibilityLabel("Amount \(viewModel.formattedAmount(for: goal.id))")
            }

            if viewModel.isSingleGoal {
                Text("100%")
                    .font(.title3)
                    .fontWeight(.medium)
                    .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
            } else if viewModel.isReadOnly {
                Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                    .font(.title3)
                    .fontWeight(.medium)
                    .accessibilityLabel(
                        "\(goal.name) \(viewModel.displayPercents[goal.id] ?? 0) percent, locked"
                    )
            } else {
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
                    Text("%")
                        .font(.title3)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.callout)
            .foregroundStyle(viewModel.canLock || viewModel.isReadOnly ? .secondary : .orange)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var lockButton: some View {
        Button {
            viewModel.requestLock()
        } label: {
            Group {
                if viewModel.isLocking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Lock this split")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canLock)
        .accessibilityLabel("Lock this split")
        .accessibilityHint(
            viewModel.canLock
                ? "Locks opening amounts and creates History entry"
                : "Enabled when percentages total 100 percent"
        )
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

#Preview("Single-goal 8b") {
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
