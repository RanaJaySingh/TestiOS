import SwiftUI

/// Transfer between goals — design frames 16 / 16a / 16b / 16c (PRD R14, Spec BR-7 / §4.2 J4).
/// Visual: PiSheet chrome, PiCard From/To/amount/preview, LightBlueChip ₹ amounts, PrimaryCTA Move.
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
        PiSheet(
            title: "Transfer",
            helper: TransferService.caption
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
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
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PiColors.backgroundApp)
            .accessibilityIdentifier("goals.transfer.header")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PiColors.backgroundApp, for: .navigationBar)
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

    private var selectors: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
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
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text(title)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                if goals.isEmpty {
                    Text("No goals available")
                        .font(PiTypography.body())
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
                    .tint(PiColors.navyPrimary)
                    .accessibilityIdentifier(accessibilityID)
                }
            }
        }
    }

    private var amountSection: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Amount")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₹")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.amountRupeesText },
                            set: { viewModel.setAmountRupeesText($0) }
                        )
                    )
                    .keyboardType(.numberPad)
                    .font(PiTypography.amountHero())
                    .foregroundStyle(PiColors.navyPrimary)
                    .monospacedDigit()
                    .accessibilityIdentifier("goals.transfer.amount")
                }
                if let from = viewModel.fromGoal {
                    Text("Available: \(viewModel.formattedSaved(for: from))")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("goals.transfer.available")
                }
            }
        }
    }

    private var chipsRow: some View {
        HStack(spacing: DesignTokens.Space.s12) {
            ForEach(viewModel.chipRupees, id: \.self) { rupees in
                let title = viewModel.formattedPaisa(TransferService.paisa(fromRupees: rupees))
                let selected = viewModel.amountRupeesText == String(rupees)
                LightBlueChip(
                    title: title,
                    isSelected: selected,
                    accessibilityIdentifier: "goals.transfer.chip.\(rupees)"
                ) {
                    viewModel.applyChip(rupees: rupees)
                }
            }
        }
        .accessibilityIdentifier("goals.transfer.chips")
    }

    private func afterTransferPreview(_ preview: TransferService.BalancePreview) -> some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("After transfer")
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                previewRow(
                    name: preview.fromName,
                    before: preview.fromBefore,
                    after: preview.fromAfter,
                    isSource: true
                )
                previewRow(
                    name: preview.toName,
                    before: preview.toBefore,
                    after: preview.toAfter,
                    isSource: false
                )
            }
        }
        .accessibilityIdentifier("goals.transfer.preview")
    }

    private func previewRow(name: String, before: Paisa, after: Paisa, isSource: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(PiTypography.body())
            Spacer()
            HStack(spacing: 4) {
                Text(viewModel.formattedPaisa(before))
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("→")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedPaisa(after))
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(isSource ? PiColors.destructive : PiColors.positiveGreen)
                    .monospacedDigit()
            }
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var overAmountBanner: some View {
        Text(TransferService.overAmountMessage)
            .font(PiTypography.caption())
            .foregroundStyle(PiColors.destructive)
            .padding(DesignTokens.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PiColors.destructive.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .accessibilityIdentifier("goals.transfer.overAmount")
    }

    private var completeBanner: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Transfer complete")
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                Text(viewModel.completionMessage ?? "")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                Text("Standing split unchanged.")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("goals.transfer.complete")
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(viewModel.phase == .overAmount ? PiColors.destructive : Color.secondary)
            .accessibilityIdentifier("goals.transfer.status")
    }

    private var moveButton: some View {
        PrimaryCTA(
            title: viewModel.isMoving ? "Moving…" : "Move",
            isEnabled: viewModel.canMove,
            accessibilityIdentifier: "goals.transfer.move"
        ) {
            Task { await viewModel.confirmMove() }
        }
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
    .piPlannerTheme()
}

/// Preview-only persistence (does not touch disk).
private final class PersistenceServicePreview: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
