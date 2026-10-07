import SwiftUI

/// Ask tab — idle / answer / proposal / unavailable chrome (PIP-63 behaviour, PIP-95 visuals).
/// Consumes DesignTokens + Components (`LightBlueChip`, `PiCard`, `ProposalCard`, CTAs).
struct AskTabView: View {
    var persistence: (any PersistenceServicing)? = nil
    var goals: [Goal] = []
    var standingSplits: [StandingSplit] = []
    var accounts: [Account] = []
    var grok: any GrokServicing = StubGrokService()
    var formatting: any FormattingServicing = FormattingService()

    @StateObject private var viewModel: AskViewModel
    @StateObject private var goalFormHost = GoalChatViewModel()

    init(
        persistence: (any PersistenceServicing)? = nil,
        goals: [Goal] = [],
        standingSplits: [StandingSplit] = [],
        accounts: [Account] = [],
        grok: any GrokServicing = StubGrokService(),
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.persistence = persistence
        self.goals = goals
        self.standingSplits = standingSplits
        self.accounts = accounts
        self.grok = grok
        self.formatting = formatting
        _viewModel = StateObject(
            wrappedValue: AskViewModel(
                goals: goals,
                standingSplits: standingSplits,
                accounts: accounts,
                persistence: persistence,
                formatting: formatting,
                grok: grok
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                header
                if viewModel.phase == .unavailable {
                    unavailableSection
                } else {
                    chipsRow
                    composer
                }
                resultSection
                if viewModel.phase == .invalidDraft {
                    invalidDraftActions
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(PiTypography.caption())
                        .foregroundStyle(PiColors.destructive)
                }
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ask.tab")
        .onAppear {
            viewModel.updateLedger(
                goals: goals,
                standingSplits: standingSplits,
                accounts: accounts
            )
        }
        .onChange(of: goals.map(\.id)) { _ in
            viewModel.updateLedger(
                goals: goals,
                standingSplits: standingSplits,
                accounts: accounts
            )
        }
        .sheet(item: $viewModel.presentedSheet) { destination in
            sheetContent(for: destination)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Ask")
                .font(PiTypography.title())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.headerCaption)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chipsRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Suggestions")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            AskSuggestionChips(texts: viewModel.suggestionChips) { chip in
                viewModel.selectChip(chip)
            }
            .accessibilityIdentifier("ask.chips")
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            TextField(viewModel.inputPlaceholder, text: $viewModel.query)
                .font(PiTypography.body())
                .padding(.horizontal, DesignTokens.Space.s16)
                .padding(.vertical, DesignTokens.Space.s12)
                .background(PiColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                        .strokeBorder(PiColors.navyPrimary.opacity(0.18), lineWidth: 1)
                )
                .accessibilityIdentifier("ask.query")
                .submitLabel(.send)
                .onSubmit {
                    viewModel.submit()
                }

            PrimaryCTA(
                title: "Ask",
                isEnabled: viewModel.canSubmit,
                accessibilityIdentifier: "ask.submit",
                action: { viewModel.submit() }
            )
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let followUp = viewModel.followUpMessage, viewModel.phase != .proposal {
            Text(followUp)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ask.followUp")
        }

        if viewModel.phase == .plainAnswer, let answerText = viewModel.answerText {
            PiCard(padding: DesignTokens.Space.s16) {
                Text(answerText)
                    .font(PiTypography.body())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("ask.answer")
        }

        if viewModel.phase == .proposal,
           let title = viewModel.proposalTitle,
           let summary = viewModel.proposalSummary {
            ProposalCard(
                title: title,
                summary: summary,
                checkedByLabel: viewModel.checkedByLabel,
                onEdit: { viewModel.editProposal() },
                onConfirm: { viewModel.confirmProposal() }
            )
        }
    }

    private var unavailableSection: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("Grok unavailable")
                    .font(PiTypography.title())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ask.unavailable.title")

                Text(AskService.unavailableMessage)
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Template sentences")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                AskSuggestionChips(texts: viewModel.unavailableTemplates) { template in
                    viewModel.selectUnavailableTemplate(template)
                }
                .accessibilityIdentifier("ask.unavailable.templates")

                VStack(spacing: DesignTokens.Space.s12) {
                    PrimaryCTA(
                        title: AskService.useFormTitle,
                        accessibilityIdentifier: "ask.unavailable.form",
                        action: { viewModel.openGoalForm(prefill: nil) }
                    )
                    SecondaryCTA(
                        title: AskService.openStandingSplitTitle,
                        style: .outline,
                        accessibilityIdentifier: "ask.unavailable.split",
                        action: { viewModel.openStandingSplit() }
                    )
                }
            }
        }
        .accessibilityIdentifier("ask.unavailable")
    }

    private var invalidDraftActions: some View {
        SecondaryCTA(
            title: AskService.useFormTitle,
            style: .outline,
            accessibilityIdentifier: "ask.invalid.form",
            action: { viewModel.openGoalForm(prefill: nil) }
        )
    }

    @ViewBuilder
    private func sheetContent(for destination: AskSheetDestination) -> some View {
        NavigationStack {
            switch destination {
            case .transfer(let prefill):
                if let persistence {
                    TransferFlow(
                        goals: goals,
                        standingSplits: standingSplits,
                        persistence: persistence,
                        formatting: formatting,
                        prefill: prefill,
                        onCompleted: { viewModel.dismissSheet() }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { viewModel.dismissSheet() }
                        }
                    }
                } else {
                    Text("Transfer needs a saved plan.")
                        .font(PiTypography.body())
                        .padding(DesignTokens.Space.s16)
                }
            case .standingSplit:
                if let persistence {
                    StandingSplitView(
                        viewModel: StandingSplitViewModel(
                            goals: goals,
                            persistence: persistence,
                            standingSplits: standingSplits
                        ),
                        onDismiss: { viewModel.dismissSheet() }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { viewModel.dismissSheet() }
                        }
                    }
                } else {
                    Text("Standing split needs a saved plan.")
                        .font(PiTypography.body())
                        .padding(DesignTokens.Space.s16)
                }
            case .goalForm(let proposal):
                GoalFormView(viewModel: goalFormHost) {
                    viewModel.dismissSheet()
                }
                .onAppear {
                    goalFormHost.reset()
                    goalFormHost.useFormPath()
                    if let proposal {
                        goalFormHost.formDraft = GoalFormDraft(from: proposal, now: Date())
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { viewModel.dismissSheet() }
                    }
                }
            }
        }
    }
}

/// Suggestion / template chips — light-blue fill via shared `LightBlueChip` (frames 19 / 19c).
private struct AskSuggestionChips: View {
    let texts: [String]
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            ForEach(texts, id: \.self) { text in
                LightBlueChip(
                    title: text,
                    isSelected: false,
                    accessibilityIdentifier: "ask.chip.\(text.prefix(24))",
                    action: { onTap(text) }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("Ask · idle") {
    NavigationStack {
        AskTabView(goals: DemoSeed.sampleGoals, accounts: DemoSeed.sampleAccounts)
    }
    .piPlannerTheme()
}

#Preview("Ask · unavailable") {
    NavigationStack {
        AskTabView(
            goals: DemoSeed.sampleGoals,
            accounts: DemoSeed.sampleAccounts,
            grok: StubGrokService(isUnavailable: true)
        )
    }
    .piPlannerTheme()
}
