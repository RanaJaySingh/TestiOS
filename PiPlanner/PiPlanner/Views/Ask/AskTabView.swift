import SwiftUI

/// Ask tab — chips, Grok stub answers / proposal cards, unavailable & invalid-draft fallbacks (PIP-63).
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
            VStack(alignment: .leading, spacing: 16) {
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
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Ask")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.headerCaption)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var chipsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowChips(texts: viewModel.suggestionChips) { chip in
                viewModel.selectChip(chip)
            }
            .accessibilityIdentifier("ask.chips")
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(viewModel.inputPlaceholder, text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("ask.query")
                .submitLabel(.send)
                .onSubmit {
                    viewModel.submit()
                }

            Button("Ask") {
                viewModel.submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
            .accessibilityIdentifier("ask.submit")
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if let followUp = viewModel.followUpMessage, viewModel.phase != .proposal {
            Text(followUp)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ask.followUp")
        }

        if viewModel.phase == .plainAnswer, let answerText = viewModel.answerText {
            Text(answerText)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Grok unavailable")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ask.unavailable.title")

            Text(AskService.unavailableMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Template sentences")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowChips(texts: viewModel.unavailableTemplates) { template in
                viewModel.selectUnavailableTemplate(template)
            }
            .accessibilityIdentifier("ask.unavailable.templates")

            HStack(spacing: 12) {
                Button(AskService.useFormTitle) {
                    viewModel.openGoalForm(prefill: nil)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ask.unavailable.form")

                Button(AskService.openStandingSplitTitle) {
                    viewModel.openStandingSplit()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ask.unavailable.split")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("ask.unavailable")
    }

    private var invalidDraftActions: some View {
        Button(AskService.useFormTitle) {
            viewModel.openGoalForm(prefill: nil)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("ask.invalid.form")
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
                        .padding()
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
                        .padding()
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

/// Simple wrapping chip row (no FlowLayout dependency).
private struct FlowChips: View {
    let texts: [String]
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(texts, id: \.self) { text in
                Button {
                    onTap(text)
                } label: {
                    Text(text)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ask.chip.\(text.prefix(24))")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AskTabView(goals: DemoSeed.sampleGoals, accounts: DemoSeed.sampleAccounts)
    }
}
