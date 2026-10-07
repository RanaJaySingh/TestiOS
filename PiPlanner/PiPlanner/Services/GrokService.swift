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
    /// Spec: stubbed answers for Ask queries.
    func askQuestion(query: String) -> Result<AskResponse, GrokError>
}

/// Deterministic Grok stub for demo + unit tests (PRD R5 / R19, Spec §3.3 / §4.3).
struct StubGrokService: GrokServicing {
    /// When true, all analyze / ask calls fail with `.unavailable` (frame 5c).
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

    func askQuestion(query: String) -> Result<AskResponse, GrokError> {
        if isUnavailable {
            return .failure(.unavailable)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.invalidDraft)
        }
        // Frame 16c — Ask can propose a Transfer that opens pre-filled.
        let lowered = trimmed.lowercased()
        if lowered.contains("transfer") || lowered.contains("move") {
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

    /// Follow-up copy for the n-th clarification (0-based), cycling the stub list.
    static func followUpQuestion(at index: Int) -> String {
        let safe = max(index, 0) % followUpQuestions.count
        return followUpQuestions[safe]
    }
}
