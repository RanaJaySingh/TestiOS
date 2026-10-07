import Combine
import Foundation

/// Destination sheet opened from an Ask proposal Confirm/Edit (13f / 16c / standing split).
enum AskSheetDestination: Equatable, Identifiable {
    case transfer(TransferService.Prefill)
    case standingSplit
    case goalForm(GoalProposal?)

    var id: String {
        switch self {
        case .transfer:
            return "transfer"
        case .standingSplit:
            return "standingSplit"
        case .goalForm:
            return "goalForm"
        }
    }
}

/// View model for Ask tab — frames 19 / 19a–19d (PIP-63).
@MainActor
final class AskViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var phase: AskPhase = .input
    @Published private(set) var answerText: String?
    @Published private(set) var proposedAction: ProposedAction?
    @Published private(set) var followUpMessage: String?
    @Published private(set) var invalidFollowUpCount = 0
    @Published var presentedSheet: AskSheetDestination?
    @Published private(set) var errorMessage: String?

    var goals: [Goal]
    var standingSplits: [StandingSplit]
    var accounts: [Account]
    let persistence: (any PersistenceServicing)?
    let formatting: any FormattingServicing
    private let grok: any GrokServicing

    var suggestionChips: [String] { GrokProposalOrchestrator.askStarters }
    var askStarters: [String] { GrokProposalOrchestrator.askStarters }
    var unavailableTemplates: [String] { GrokProposalOrchestrator.unavailableTemplates }
    var checkedByLabel: String { GrokProposalOrchestrator.checkedByLabel }
    var headerCaption: String { AskService.headerCaption }
    var inputPlaceholder: String { AskService.inputPlaceholder }

    var ledgerSnapshot: GrokProposalOrchestrator.LedgerSnapshot {
        GrokProposalOrchestrator.LedgerSnapshot(
            goals: goals,
            standingSplits: standingSplits,
            accounts: accounts
        )
    }

    var canSubmit: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var proposalTitle: String? {
        guard let proposedAction else { return nil }
        return AskService.proposalTitle(for: proposedAction)
    }

    var proposalSummary: String? {
        guard let proposedAction else { return nil }
        return AskService.proposalSummary(
            for: proposedAction,
            goals: goals,
            formatting: formatting
        )
    }

    var engineContext: AskEngineContext {
        AskEngineContext.make(goals: goals, accounts: accounts)
    }

    init(
        goals: [Goal] = [],
        standingSplits: [StandingSplit] = [],
        accounts: [Account] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService(),
        grok: any GrokServicing = StubGrokService()
    ) {
        self.goals = goals
        self.standingSplits = standingSplits
        self.accounts = accounts
        self.persistence = persistence
        self.formatting = formatting
        self.grok = grok
        applyUnavailableIfNeeded()
    }

    /// Refresh ledger snapshot from Goals tab without resetting Ask conversation.
    func updateLedger(
        goals: [Goal],
        standingSplits: [StandingSplit],
        accounts: [Account]
    ) {
        self.goals = goals
        self.standingSplits = standingSplits
        self.accounts = accounts
    }

    func selectChip(_ text: String) {
        query = text
        submit()
    }

    func selectUnavailableTemplate(_ text: String) {
        query = text
        // Frame 19c — templates/forms work without Grok.
        if phase == .unavailable {
            openFallback(forTemplate: text)
            return
        }
        submit()
    }

    /// Direct fallbacks when Grok is unavailable (forms / sliders / templates).
    func openFallback(forTemplate text: String) {
        let lowered = text.lowercased()
        if StubGrokService.isTransferAction(lowered) {
            presentedSheet = .transfer(StubGrokService.demoTransferPrefill)
            return
        }
        if StubGrokService.isAddGoalAction(lowered) {
            presentedSheet = .goalForm(StubGrokService.demoVacationProposal)
            return
        }
        if StubGrokService.isChangeSplitAction(lowered) || lowered.contains("split") {
            presentedSheet = .standingSplit
            return
        }
        presentedSheet = .goalForm(nil)
    }

    func submit() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        answerText = nil
        proposedAction = nil
        followUpMessage = nil

        // PIP-108 — Grok draft → engine validate → confirm card (or fallback).
        switch GrokProposalOrchestrator.processAsk(
            query: text,
            grok: grok,
            ledger: ledgerSnapshot,
            formatting: formatting
        ) {
        case .unavailable:
            phase = .unavailable
            followUpMessage = AskService.unavailableMessage
            proposedAction = nil
        case .invalidDraft:
            handleInvalidDraft()
        case .plainAnswer(let answer):
            invalidFollowUpCount = 0
            phase = .plainAnswer
            answerText = answer
            proposedAction = nil
        case .confirmable(let action):
            invalidFollowUpCount = 0
            phase = .proposal
            proposedAction = action
            answerText = nil
        }
    }

    func confirmProposal() {
        guard let proposedAction else { return }
        openSheet(for: proposedAction)
    }

    func editProposal() {
        guard let proposedAction else { return }
        openSheet(for: proposedAction)
    }

    func openGoalForm(prefill: GoalProposal? = nil) {
        presentedSheet = .goalForm(prefill)
    }

    func openStandingSplit() {
        presentedSheet = .standingSplit
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func clearConversation() {
        query = ""
        answerText = nil
        proposedAction = nil
        followUpMessage = nil
        invalidFollowUpCount = 0
        errorMessage = nil
        applyUnavailableIfNeeded()
        if phase != .unavailable {
            phase = .input
        }
    }

    // MARK: - Private

    private func applyUnavailableIfNeeded() {
        if case .failure(.unavailable) = grok.askQuestion(query: "ping", engine: nil) {
            phase = .unavailable
            followUpMessage = AskService.unavailableMessage
        }
    }

    private func handleInvalidDraft() {
        // Invalid drafts never shown as cards (engine or Grok).
        proposedAction = nil
        answerText = nil
        if AskService.shouldOpenGoalFormAfterInvalid(followUpCount: invalidFollowUpCount) {
            phase = .invalidDraft
            followUpMessage = AskService.invalidThenFormMessage
            invalidFollowUpCount = 0
            presentedSheet = .goalForm(nil)
            return
        }
        invalidFollowUpCount += 1
        phase = .invalidDraft
        followUpMessage = AskService.invalidFollowUpPrompt
    }

    private func openSheet(for action: ProposedAction) {
        // Re-validate before Confirm / Edit opens a sheet (trust boundary).
        guard case .success = GrokProposalOrchestrator.validate(action, goals: goals) else {
            handleInvalidDraft()
            return
        }
        if let prefill = AskService.transferPrefill(from: action) {
            presentedSheet = .transfer(prefill)
            return
        }
        if let proposal = AskService.goalProposal(from: action) {
            presentedSheet = .goalForm(proposal)
            return
        }
        if AskService.isChangeSplit(action) {
            presentedSheet = .standingSplit
        }
    }
}
