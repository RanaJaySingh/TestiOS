import Foundation

/// PIP-108 — Grok orchestrator: drafts → engine validate → confirmable card.
///
/// **Trust boundary:** Grok output is a draft only. Money movement and final
/// amounts stay in `LedgerEngineCore` / Transfer / Standing / GoalValidation.
/// This type never mutates `PersistedAppState` or computes settlement amounts.
enum GrokProposalOrchestrator {
    /// Ledger snapshot used to validate Ask / Transfer / Standing drafts.
    struct LedgerSnapshot: Equatable, Sendable {
        var goals: [Goal]
        var standingSplits: [StandingSplit]
        var accounts: [Account]

        init(
            goals: [Goal] = [],
            standingSplits: [StandingSplit] = [],
            accounts: [Account] = []
        ) {
            self.goals = goals
            self.standingSplits = standingSplits
            self.accounts = accounts
        }

        var askEngine: AskEngineContext {
            AskEngineContext.make(goals: goals, accounts: accounts)
        }
    }

    /// Ask / Grok outcome after engine validation (frames 19 / 19a–19d).
    enum Outcome: Equatable, Sendable {
        /// Plain-text answer — no confirm card.
        case plainAnswer(String)
        /// Engine-validated draft ready for `ProposalCard` Edit / Confirm.
        case confirmable(ProposedAction)
        /// Invalid draft — never shown as a card (19d).
        case invalidDraft
        /// Grok down — template sentences / forms (19c).
        case unavailable(templates: [String])
    }

    /// Idle Ask starters (design chips) — alias of `AskService.suggestionChips`.
    static var askStarters: [String] { AskService.suggestionChips }

    /// Template sentences when Grok is unavailable (19c).
    static var unavailableTemplates: [String] { AskService.unavailableTemplateSentences }

    static let checkedByLabel = StubGrokService.checkedByLabel

    // MARK: - Ask pipeline

    /// Runs Grok Ask, then validates any action draft via engine helpers.
    /// Never surfaces an unvalidated proposal as confirmable.
    static func processAsk(
        query: String,
        grok: any GrokServicing,
        ledger: LedgerSnapshot,
        formatting: any FormattingServicing = FormattingService()
    ) -> Outcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalidDraft }

        switch grok.askQuestion(query: trimmed, engine: ledger.askEngine) {
        case .failure(.unavailable):
            return .unavailable(templates: unavailableTemplates)
        case .failure:
            return .invalidDraft
        case .success(.plainAnswer(let text)):
            return .plainAnswer(text)
        case .success(.actionProposal(let action)):
            switch validate(action, goals: ledger.goals) {
            case .success(let valid):
                return .confirmable(valid)
            case .failure:
                return .invalidDraft
            }
        }
    }

    // MARK: - Engine validation (drafts only)

    /// Validates a Grok `ProposedAction` against ledger goals.
    /// Does **not** apply transfers, create goals, or rewrite standing splits.
    static func validate(
        _ action: ProposedAction,
        goals: [Goal]
    ) -> Result<ProposedAction, AppError> {
        switch action {
        case .transfer(let from, let to, let amount):
            return validateTransfer(from: from, to: to, amount: amount, goals: goals)
        case .addGoal(let proposal):
            return validateAddGoal(proposal)
        case .changeSplit(let newSplit):
            return validateChangeSplit(newSplit, goals: goals)
        }
    }

    /// Validates Goal-chat proposal list (shares must total 100%; each goal formable).
    static func validateGoalProposals(
        _ proposals: [GoalProposal]
    ) -> Result<[GoalProposal], AppError> {
        guard !proposals.isEmpty else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "proposals",
                        message: "At least one goal proposal is required.",
                        code: .emptyName
                    )
                )
            )
        }

        for proposal in proposals {
            if let error = addGoalValidationError(proposal) {
                return .failure(.validationError(error))
            }
        }

        let shares = proposals.map(\.sharePercentage)
        guard StandingSplitService.isValidHundredPercent(shares) else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "sharePercentage",
                        message: StandingSplitService.shortfallMessage(for: shares)
                            ?? "Splits must total 100%.",
                        code: .splitNotHundred
                    )
                )
            )
        }

        return .success(proposals)
    }

    // MARK: - Private validators

    private static func validateTransfer(
        from: UUID,
        to: UUID,
        amount: Paisa,
        goals: [Goal]
    ) -> Result<ProposedAction, AppError> {
        guard TransferService.goal(id: from, in: goals) != nil else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "fromGoalId",
                        message: "From goal not found.",
                        code: .emptyName
                    )
                )
            )
        }
        guard TransferService.goal(id: to, in: goals) != nil else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "toGoalId",
                        message: "To goal not found.",
                        code: .emptyName
                    )
                )
            )
        }
        guard from != to else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "toGoalId",
                        message: "From and To must differ.",
                        code: .emptyName
                    )
                )
            )
        }
        // Engine gate — amount ≤ From saved (TransferService / LedgerEngineCore path).
        guard TransferService.canMove(
            fromGoalId: from,
            toGoalId: to,
            amountPaisa: amount,
            goals: goals
        ) else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "amount",
                        message: TransferService.overAmountMessage,
                        code: .amountExceedsSaved
                    )
                )
            )
        }
        return .success(.transfer(from: from, to: to, amount: amount))
    }

    private static func validateAddGoal(
        _ proposal: GoalProposal
    ) -> Result<ProposedAction, AppError> {
        if let error = addGoalValidationError(proposal) {
            return .failure(.validationError(error))
        }
        return .success(.addGoal(proposal: proposal))
    }

    private static func addGoalValidationError(_ proposal: GoalProposal) -> ValidationError? {
        let name = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = proposal.suggestedTarget ?? 0
        let now = Date()
        let end = now.addingTimeInterval(86_400 * 365)
        let errors = GoalValidationService.validationErrors(
            name: name,
            targetPaisa: target,
            startDate: now,
            endDate: end
        )
        return errors.first
    }

    private static func validateChangeSplit(
        _ newSplit: [StandingSplit],
        goals: [Goal]
    ) -> Result<ProposedAction, AppError> {
        guard !newSplit.isEmpty else {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "standingSplits",
                        message: "Standing split cannot be empty.",
                        code: .splitNotHundred
                    )
                )
            )
        }

        let goalIDs = Set(goals.map(\.id))
        for split in newSplit {
            guard goalIDs.contains(split.goalId) else {
                return .failure(
                    .validationError(
                        ValidationError(
                            field: "goalId",
                            message: "Standing split references an unknown goal.",
                            code: .emptyName
                        )
                    )
                )
            }
        }

        // Cover every current goal (missing → 0) so BR-2 / StandingSplitService applies.
        var percentages: [UUID: Decimal] = Dictionary(
            uniqueKeysWithValues: goals.map { ($0.id, Decimal(0)) }
        )
        for split in newSplit {
            percentages[split.goalId] = split.percentage
        }

        do {
            _ = try StandingSplitService.makeStandingSplits(goals: goals, percentages: percentages)
            return .success(.changeSplit(newSplit: newSplit))
        } catch let error as AppError {
            return .failure(error)
        } catch {
            return .failure(
                .validationError(
                    ValidationError(
                        field: "percentages",
                        message: error.localizedDescription,
                        code: .splitNotHundred
                    )
                )
            )
        }
    }
}
