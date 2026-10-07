import Foundation

// MARK: - Spec §3.3 contracts

/// Spec §3.3 — GoalProposal
struct GoalProposal: Equatable, Sendable, Identifiable {
    var id: UUID
    var name: String
    /// Standing split share 0.0–1.0
    var sharePercentage: Decimal
    /// Suggested target in paisa (app convention; Spec lists Decimal)
    var suggestedTarget: Paisa?

    init(
        id: UUID = UUID(),
        name: String,
        sharePercentage: Decimal,
        suggestedTarget: Paisa? = nil
    ) {
        self.id = id
        self.name = name
        self.sharePercentage = sharePercentage
        self.suggestedTarget = suggestedTarget
    }
}

/// Spec §3.3 — ProposedAction (Ask tab; stubbed for contract completeness)
enum ProposedAction: Equatable, Sendable {
    case addGoal(proposal: GoalProposal)
    case transfer(from: UUID, to: UUID, amount: Paisa)
    case changeSplit(newSplit: [StandingSplit])
}

/// Spec §3.3 — AskResponse
enum AskResponse: Equatable, Sendable {
    case plainAnswer(text: String)
    case actionProposal(action: ProposedAction)
}

/// Richer analysis outcome used by Goal chat (frames 5 / 5a / 5b).
enum GrokGoalAnalysis: Equatable, Sendable {
    case proposals([GoalProposal])
    case needsClarification(question: String)
}

/// Spec §3.3 — GrokService (stub)
protocol GrokServicing: Sendable {
    /// Spec: returns stubbed goal proposals based on input text.
    func analyzeGoals(input: String) -> Result<[GoalProposal], GrokError>
    /// Goal-chat helper: proposals or a clarification follow-up (5a).
    func analyzeGoalInput(_ input: String) -> Result<GrokGoalAnalysis, GrokError>
    /// Spec: stubbed answers for Ask queries (optional engine context for 19a numbers).
    func askQuestion(query: String, engine: AskEngineContext?) -> Result<AskResponse, GrokError>
}

extension GrokServicing {
    /// Convenience — Ask without ledger snapshot (tests / Transfer 16c).
    func askQuestion(query: String) -> Result<AskResponse, GrokError> {
        askQuestion(query: query, engine: nil)
    }
}

/// Deterministic Grok stub for demo + unit tests (PRD R5 / R18 / R19, Spec §3.3 / §4.3).
/// PIP-65 may extend happy-path persona seeding — keep hooks small and additive.
struct StubGrokService: GrokServicing {
    /// When true, all analyze / ask calls fail with `.unavailable` (frames 5c / 19c).
    var isUnavailable: Bool

    /// Design / demo happy-path proposal: Car 60%, Emergency Fund 40%.
    static let happyPathProposals: [GoalProposal] = [
        GoalProposal(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Car",
            sharePercentage: Decimal(string: "0.6")!,
            suggestedTarget: 50_000_000
        ),
        GoalProposal(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Emergency Fund",
            sharePercentage: Decimal(string: "0.4")!,
            suggestedTarget: 20_000_000
        )
    ]

    /// Demo Vacation goal for Ask add-goal proposals (13f).
    static let demoVacationProposal = GoalProposal(
        id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
        name: "Vacation",
        sharePercentage: Decimal(string: "0.2")!,
        suggestedTarget: 5_000_000
    )

    static let checkedByLabel = "Checked by PiPlanner. Estimate."

    static let followUpQuestions: [String] = [
        "What are you saving for? For example: a car, emergency fund, or a trip.",
        "Roughly how much do you want for each goal, and what share of new savings should each get?"
    ]

    init(isUnavailable: Bool = false) {
        self.isUnavailable = isUnavailable
    }

    func analyzeGoals(input: String) -> Result<[GoalProposal], GrokError> {
        switch analyzeGoalInput(input) {
        case .failure(let error):
            return .failure(error)
        case .success(.proposals(let proposals)):
            return .success(proposals)
        case .success(.needsClarification):
            return .failure(.invalidDraft)
        }
    }

    func analyzeGoalInput(_ input: String) -> Result<GrokGoalAnalysis, GrokError> {
        if isUnavailable {
            return .failure(.unavailable)
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(.needsClarification(question: Self.followUpQuestions[0]))
        }

        if Self.isVague(trimmed) {
            return .success(.needsClarification(question: Self.followUpQuestions[0]))
        }

        return .success(.proposals(Self.happyPathProposals))
    }

    /// Demo Transfer proposal (frame 16c): Car → Emergency Fund · ₹5,000.
    static let demoTransferPrefill = TransferService.Prefill(
        fromGoalId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        toGoalId: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        amountPaisa: 500_000
    )

    func askQuestion(query: String, engine: AskEngineContext?) -> Result<AskResponse, GrokError> {
        if isUnavailable {
            return .failure(.unavailable)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isInvalidAskDraft(trimmed) {
            return .failure(.invalidDraft)
        }

        let lowered = trimmed.lowercased()
        let formatting = FormattingService()
        let goals = engine?.goals ?? []

        // Questions (chips / “what if…”) stay plain answers — not proposal cards (19a).
        if !Self.isInformationalQuestion(lowered) {
            // Frame 16c — Transfer / move money.
            if Self.isTransferAction(lowered) {
                let prefill = Self.demoTransferPrefill
                return .success(
                    .actionProposal(
                        action: .transfer(
                            from: prefill.fromGoalId!,
                            to: prefill.toGoalId!,
                            amount: prefill.amountPaisa ?? 0
                        )
                    )
                )
            }

            // Frame 13f — Add goal proposal.
            if Self.isAddGoalAction(lowered) {
                return .success(.actionProposal(action: .addGoal(proposal: Self.demoVacationProposal)))
            }

            // Standing split change (imperative).
            if Self.isChangeSplitAction(lowered) {
                let split = Self.demoChangeSplit(goals: goals)
                return .success(.actionProposal(action: .changeSplit(newSplit: split)))
            }
        }

        // Frame 19a — plain answer using engine numbers when provided.
        if let engine {
            return .success(
                .plainAnswer(text: AskService.plainAnswer(for: trimmed, engine: engine, formatting: formatting))
            )
        }
        // PIP-65 / PIP-63 — additive happy-path Ask copy for Car / Emergency Fund (design).
        if lowered.contains("car") || lowered.contains("emergency") {
            return .success(
                .plainAnswer(text: Self.happyPathAskAnswer)
            )
        }
        return .success(
            .plainAnswer(
                text: "Your plan assigns every rupee to a named goal. Ask again after setup for live numbers."
            )
        )
    }

    /// Design-matched Ask answer for the Car / Emergency Fund demo plan (PIP-65).
    static let happyPathAskAnswer =
        "Your plan puts 60% of new credits toward Car and 40% toward Emergency Fund."

    /// Maps a Transfer ProposedAction to TransferService.Prefill (Ask → Transfer).
    static func transferPrefill(from action: ProposedAction) -> TransferService.Prefill? {
        guard case .transfer(let from, let to, let amount) = action else { return nil }
        return TransferService.Prefill(fromGoalId: from, toGoalId: to, amountPaisa: amount)
    }

    /// Demo standing-split proposal: equal shares across current goals (fallback 50/50 Car/Emergency).
    static func demoChangeSplit(goals: [Goal]) -> [StandingSplit] {
        if goals.count >= 2 {
            let share = Decimal(1) / Decimal(goals.count)
            return goals.map { StandingSplit(goalId: $0.id, percentage: share) }
        }
        if let only = goals.first {
            return [StandingSplit(goalId: only.id, percentage: 1)]
        }
        let car = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let emergency = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        return [
            StandingSplit(goalId: car, percentage: Decimal(string: "0.5")!),
            StandingSplit(goalId: emergency, percentage: Decimal(string: "0.5")!)
        ]
    }

    /// Vague when short / filler-only, or lacks concrete goal nouns from the demo set.
    static func isVague(_ input: String) -> Bool {
        let lowered = input.lowercased()
        let concreteTokens = ["car", "emergency", "fund", "house", "home", "trip", "vacation", "wedding"]
        if concreteTokens.contains(where: { lowered.contains($0) }) {
            return false
        }
        let fillerOnly: Set<String> = [
            "goals", "goal", "save", "savings", "money", "something", "idk",
            "help", "plan", "please", "stuff", "things"
        ]
        let tokens = lowered
            .split { !$0.isLetter }
            .map(String.init)
            .filter { !$0.isEmpty }
        if tokens.isEmpty { return true }
        if tokens.count <= 4, tokens.allSatisfy({ fillerOnly.contains($0) }) {
            return true
        }
        // Longer text without concrete nouns still needs clarification for the stub.
        return !concreteTokens.contains(where: { lowered.contains($0) })
    }

    /// Ask 19d — stub invalid drafts (never returned as proposal cards).
    static func isInvalidAskDraft(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let lowered = trimmed.lowercased()
        if lowered.contains("invalid draft") || lowered == "???" || lowered == "asdf" {
            return true
        }
        return false
    }

    /// “What / why / how / if …” → explain only; do not emit action proposals.
    static func isInformationalQuestion(_ lowered: String) -> Bool {
        lowered.hasPrefix("what ")
            || lowered.hasPrefix("why ")
            || lowered.hasPrefix("how ")
            || lowered.contains("what happens")
            || lowered.contains("why is")
    }

    static func isTransferAction(_ lowered: String) -> Bool {
        lowered.contains("transfer") || lowered.contains("move")
    }

    static func isAddGoalAction(_ lowered: String) -> Bool {
        lowered.contains("add") && (lowered.contains("goal") || lowered.contains("vacation") || lowered.contains("trip"))
            || lowered.contains("new goal")
            || (lowered.contains("vacation") && (lowered.contains("add") || lowered.contains("by ")))
    }

    static func isChangeSplitAction(_ lowered: String) -> Bool {
        (lowered.contains("change") || lowered.contains("update"))
            && (lowered.contains("split") || lowered.contains("standing"))
            || lowered == "standing split"
            || lowered.hasPrefix("change the standing")
    }

    /// Follow-up copy for the n-th clarification (0-based), cycling the stub list.
    static func followUpQuestion(at index: Int) -> String {
        let safe = max(index, 0) % followUpQuestions.count
        return followUpQuestions[safe]
    }
}
