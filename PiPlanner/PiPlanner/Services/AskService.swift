import Foundation

/// Ask tab UI phases (frames 19 / 19a–19d).
enum AskPhase: String, Equatable, Sendable {
    case input
    case plainAnswer
    case proposal
    case unavailable
    case invalidDraft
}

/// Ledger snapshot for Ask plain answers that must use engine numbers (19a).
/// Kept separate from Grok persona seeding (PIP-65) so stub answers stay extensible.
struct AskEngineContext: Equatable, Sendable {
    var goals: [Goal]
    var totalSavingsPaisa: Paisa

    init(goals: [Goal] = [], totalSavingsPaisa: Paisa = 0) {
        self.goals = goals
        self.totalSavingsPaisa = totalSavingsPaisa
    }

    static func make(goals: [Goal], accounts: [Account]) -> AskEngineContext {
        AskEngineContext(
            goals: goals,
            totalSavingsPaisa: GoalsTabService.totalSavingsPaisa(accounts: accounts, goals: goals)
        )
    }
}

/// Pure Ask helpers — chips, engine answers, proposal copy, fallback policy (PIP-63).
/// Linux-testable; amounts remain Int64 paisa.
enum AskService {
    /// Design frame 19 suggestion chips / Ask starters (PIP-108).
    static let suggestionChips: [String] = [
        "What happens if I change the split?",
        "Why is inflation 5%?"
    ]

    /// Idle Ask starters — same as suggestion chips (PIP-108 naming).
    static var askStarters: [String] { suggestionChips }

    /// Frame 19c template sentences when Grok is unavailable.
    static let unavailableTemplateSentences: [String] = [
        "Transfer ₹5,000 from Car to Emergency Fund",
        "Add a ₹50,000 vacation by March",
        "Change the standing split"
    ]

    static let headerCaption =
        "Ask about your plan, or tell Grok what to do. Changes come back as a card to confirm."

    static let inputPlaceholder = "Ask Grok"

    static let checkedByLabel = StubGrokService.checkedByLabel

    /// Frame 19d — ask once more after an invalid draft, then Goal form.
    static let maxInvalidFollowUps = 1

    static let invalidFollowUpPrompt =
        "I couldn’t build a valid action from that. Try one clearer sentence — for example a transfer, a new goal, or a split change."

    static let invalidThenFormMessage =
        "Let’s use the Goal form so you can enter details precisely."

    static let unavailableMessage =
        "Grok is unavailable. Use a form, sliders, or a template sentence below."

    static let useFormTitle = "Use Goal form"

    static let openStandingSplitTitle = "Standing split"

    // MARK: - Plain answers (19a)

    /// Builds a plain-text answer that includes live engine numbers when available.
    static func plainAnswer(
        for query: String,
        engine: AskEngineContext,
        formatting: any FormattingServicing
    ) -> String {
        let lowered = query.lowercased()
        if lowered.contains("inflation") {
            return inflationAnswer()
        }
        if lowered.contains("split") {
            return splitAnswer(engine: engine, formatting: formatting)
        }
        return planSummaryAnswer(engine: engine, formatting: formatting)
    }

    static func inflationAnswer() -> String {
        "PiPlanner starts at 5% inflation as a cautious default. It’s an estimate, not a guarantee — you can change it on any goal."
    }

    static func splitAnswer(
        engine: AskEngineContext,
        formatting: any FormattingServicing
    ) -> String {
        guard !engine.goals.isEmpty else {
            return "Changing the standing split only affects the next credit. Saved amounts stay where they are."
        }
        let parts = engine.goals.map { goal in
            let pct = GoalValidationService.displayPercent(fromFraction: goal.shareOfNewCredits)
            let saved = formatting.formatINR(paisa: goal.savedAmount)
            return "\(goal.name) \(pct)% (saved \(saved))"
        }
        return "If you change the standing split, the next credit uses the new %. Saved money stays put. Current split: "
            + parts.joined(separator: "; ")
            + "."
    }

    static func planSummaryAnswer(
        engine: AskEngineContext,
        formatting: any FormattingServicing
    ) -> String {
        let total = formatting.formatINR(paisa: engine.totalSavingsPaisa)
        guard !engine.goals.isEmpty else {
            return "Your plan assigns every rupee to a named goal. Total savings \(total)."
        }
        let parts = engine.goals.map { goal in
            let saved = formatting.formatINR(paisa: goal.savedAmount)
            let target = formatting.formatINR(paisa: goal.targetAmount)
            let pct = GoalValidationService.displayPercent(fromFraction: goal.shareOfNewCredits)
            return "\(goal.name) \(saved) of \(target) · \(pct)% of credits"
        }
        return "Your plan totals \(total). "
            + parts.joined(separator: "; ")
            + "."
    }

    // MARK: - Proposal presentation (19b)

    static func proposalTitle(for action: ProposedAction) -> String {
        switch action {
        case .transfer:
            return "Suggested transfer"
        case .addGoal:
            return "Suggested new goal"
        case .changeSplit:
            return "Suggested standing split"
        }
    }

    static func proposalSummary(
        for action: ProposedAction,
        goals: [Goal],
        formatting: any FormattingServicing
    ) -> String {
        switch action {
        case .transfer(let from, let to, let amount):
            let fromName = goals.first { $0.id == from }?.name ?? "From"
            let toName = goals.first { $0.id == to }?.name ?? "To"
            return TransferService.historyTitle(
                fromName: fromName,
                toName: toName,
                amountPaisa: amount,
                formatting: formatting
            )
        case .addGoal(let proposal):
            let target = proposal.suggestedTarget.map { formatting.formatINR(paisa: $0) } ?? "—"
            let pct = GoalValidationService.displayPercent(fromFraction: proposal.sharePercentage)
            return "\(proposal.name) · \(target) · \(pct)% of new credits"
        case .changeSplit(let newSplit):
            let parts = newSplit.map { split -> String in
                let name = goals.first { $0.id == split.goalId }?.name ?? "Goal"
                let pct = GoalValidationService.displayPercent(fromFraction: split.percentage)
                return "\(name) \(pct)%"
            }
            return parts.joined(separator: " · ")
        }
    }

    /// Whether Confirm/Edit should open Transfer (16c).
    static func transferPrefill(from action: ProposedAction) -> TransferService.Prefill? {
        StubGrokService.transferPrefill(from: action)
    }

    /// Whether Confirm/Edit should open Goal form (13f).
    static func goalProposal(from action: ProposedAction) -> GoalProposal? {
        guard case .addGoal(let proposal) = action else { return nil }
        return proposal
    }

    /// Whether Confirm/Edit should open Standing split.
    static func isChangeSplit(_ action: ProposedAction) -> Bool {
        if case .changeSplit = action { return true }
        return false
    }

    /// After N invalid drafts, open Goal form (19d). First invalid → follow-up only.
    static func shouldOpenGoalFormAfterInvalid(followUpCount: Int) -> Bool {
        followUpCount >= maxInvalidFollowUps
    }
}
