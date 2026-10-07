import SwiftUI

/// Transfer between goals — design frames 16 / 16a / 16b / 16c (PRD R14, Spec BR-7).
struct TransferView: View {
    @StateObject private var viewModel: TransferViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: TransferViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience entry used by Goal detail / Goals tab / Ask prefill.
    init(
        goals: [Goal],
        standingSplits: [StandingSplit] = [],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        prefill: TransferService.Prefill? = nil,
        onCompleted: (() -> Void)? = nil
    ) {
        self.init(
            viewModel: TransferViewModel(
                goals: goals,
                standingSplits: standingSplits,
                persistence: persistence,
                formatting: formatting,
                prefill: prefill,
                onCompleted: onCompleted
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                selectors
                amountSection
                chipsRow
                if viewModel.phase == .preview, let preview = viewModel.preview {
                    afterTransferPreview(preview)
                }
                if viewModel.phase == .overAmount {
                    overAmountBanner
                }
                if viewModel.phase == .complete {
                    completeBanner
                }
                statusFooter
                moveButton
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.transfer")
        .task {
            await viewModel.refreshGoals()
        }
        .onChange(of: viewModel.didComplete) { completed in
            // Keep Complete state visible briefly; caller may dismiss via Done.
            _ = completed
        }
        .alert(
            "Couldn’t transfer",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { /* cleared on next edit */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(TransferService.caption)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("goals.transfer.header")
    }

    private var selectors: some View {
        VStack(alignment: .leading, spacing: 16) {
            goalPicker(
                title: "From",
                selection: viewModel.fromGoalId,
                goals: viewModel.goals,
                accessibilityID: "goals.transfer.from"
            ) { id in
                viewModel.selectFrom(id)
            }

            goalPicker(
                title: "To",
                selection: viewModel.toGoalId,
                goals: viewModel.toCandidates,
                accessibilityID: "goals.transfer.to"
            ) { id in
                viewModel.selectTo(id)
            }
        }
    }

    private func goalPicker(
        title: String,
        selection: UUID?,
        goals: [Goal],
        accessibilityID: String,
        onSelect: @escaping (UUID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if goals.isEmpty {
                Text("No goals available")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Picker(title, selection: Binding(
                    get: { selection ?? goals[0].id },
                    set: { onSelect($0) }
                )) {
                    ForEach(goals) { goal in
                        Text("\(goal.name) · \(viewModel.formattedSaved(for: goal))")
                            .tag(goal.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(accessibilityID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.title)
                    .fontWeight(.semibold)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.amountRupeesText },
                        set: { viewModel.setAmountRupeesText($0) }
                    )
                )
                .keyboardType(.numberPad)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()
                .accessibilityIdentifier("goals.transfer.amount")
            }
            if let from = viewModel.fromGoal {
                Text("Available: \(viewModel.formattedSaved(for: from))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("goals.transfer.available")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var chipsRow: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.chipRupees, id: \.self) { rupees in
                Button {
                    viewModel.applyChip(rupees: rupees)
                } label: {
                    Text(viewModel.formattedPaisa(TransferService.paisa(fromRupees: rupees)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("goals.transfer.chip.\(rupees)")
            }
        }
        .accessibilityIdentifier("goals.transfer.chips")
    }

    private func afterTransferPreview(_ preview: TransferService.BalancePreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After transfer")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            previewRow(
                name: preview.fromName,
                before: preview.fromBefore,
                after: preview.fromAfter
            )
            previewRow(
                name: preview.toName,
                before: preview.toBefore,
                after: preview.toAfter
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("goals.transfer.preview")
    }

    private func previewRow(name: String, before: Paisa, after: Paisa) -> some View {
        HStack {
            Text(name)
                .font(.body)
            Spacer()
            Text("\(viewModel.formattedPaisa(before)) → \(viewModel.formattedPaisa(after))")
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var overAmountBanner: some View {
        Text(TransferService.overAmountMessage)
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("goals.transfer.overAmount")
    }

    private var completeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer complete")
                .font(.headline)
            Text(viewModel.completionMessage ?? "")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Standing split unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("goals.transfer.complete")
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.footnote)
            .foregroundStyle(viewModel.phase == .overAmount ? .red : .secondary)
            .accessibilityIdentifier("goals.transfer.status")
    }

    private var moveButton: some View {
        Button {
            Task { await viewModel.confirmMove() }
        } label: {
            Text(viewModel.isMoving ? "Moving…" : "Move")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canMove)
        .accessibilityIdentifier("goals.transfer.move")
        .accessibilityHint(viewModel.canMove ? "Moves the amount between goals" : "Enter a valid amount to enable")
    }
}

/// Navigation / sheet entry for Transfer (mirrors `DeleteGoalFlow`).
struct TransferFlow: View {
    let goals: [Goal]
    var standingSplits: [StandingSplit] = []
    let persistence: any PersistenceServicing
    var formatting: any FormattingServicing = FormattingService()
    var prefill: TransferService.Prefill? = nil
    var onCompleted: (() -> Void)? = nil

    var body: some View {
        TransferView(
            goals: goals,
            standingSplits: standingSplits,
            persistence: persistence,
            formatting: formatting,
            prefill: prefill,
            onCompleted: onCompleted
        )
    }
}

#Preview("Transfer") {
    NavigationStack {
        TransferView(
            goals: DemoSeed.sampleGoals,
            persistence: PersistenceServicePreview()
        )
    }
}

/// Preview-only persistence (does not touch disk).
private final class PersistenceServicePreview: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
