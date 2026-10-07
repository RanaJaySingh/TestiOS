import Combine
import Foundation

/// UI phase for Goal chat / form (frames 5, 5a, 5b, 5c, 6).
enum GoalChatPhase: Equatable, Sendable {
    case chat
    case followUp
    case proposal
    case form
    case unavailable
    case goalsDefined
}

/// Chat bubble for the Goal chat transcript.
struct GoalChatMessage: Equatable, Identifiable, Sendable {
    enum Role: Equatable, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

/// View model for Goal chat → proposal / follow-up / form → goals defined (PRD R5).
@MainActor
final class GoalChatViewModel: ObservableObject {
    @Published private(set) var phase: GoalChatPhase = .chat
    @Published private(set) var messages: [GoalChatMessage] = [
        GoalChatMessage(
            role: .assistant,
            text: "Describe the goals you’re saving for. I’ll suggest a split you can edit or confirm."
        )
    ]
    @Published var draftInput = ""
    @Published private(set) var proposals: [GoalProposal] = []
    @Published private(set) var definedGoals: [Goal] = []
    @Published private(set) var followUpCount = 0
    @Published private(set) var followUpPrompt: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var shouldNavigateToOpeningSplit = false
    @Published var formDraft = GoalFormDraft()
    @Published var showInflationPopup = false
    /// When editing a single proposal / defined goal from Edit.
    @Published private(set) var editingGoalID: UUID?

    private let grok: any GrokServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date

    var canSend: Bool {
        !draftInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase != .form
            && phase != .unavailable
    }

    var canContinue: Bool {
        GoalValidationService.canContinueWithDefinedGoals(definedGoals)
    }

    var continueDisabledReason: String? {
        GoalValidationService.splitShortfallMessage(for: definedGoals)
    }

    var checkedByLabel: String {
        GoalValidationService.checkedByLabel
    }

    var formattedProposals: [(GoalProposal, String)] {
        proposals.map { proposal in
            let target = proposal.suggestedTarget.map { formatting.formatINR(paisa: $0) } ?? "—"
            return (proposal, target)
        }
    }

    init(
        grok: any GrokServicing = StubGrokService(),
        formatting: any FormattingServicing = FormattingService(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.grok = grok
        self.formatting = formatting
        self.clock = clock
        applyUnavailableIfNeeded()
    }

    /// Clears chat/form state when re-entering Goal chat from balance entry.
    func reset() {
        phase = .chat
        messages = [
            GoalChatMessage(
                role: .assistant,
                text: "Describe the goals you’re saving for. I’ll suggest a split you can edit or confirm."
            )
        ]
        draftInput = ""
        proposals = []
        definedGoals = []
        followUpCount = 0
        followUpPrompt = nil
        errorMessage = nil
        shouldNavigateToOpeningSplit = false
        formDraft = GoalFormDraft()
        showInflationPopup = false
        editingGoalID = nil
        applyUnavailableIfNeeded()
    }

    private func applyUnavailableIfNeeded() {
        if case .failure(.unavailable) = grok.analyzeGoalInput("car") {
            phase = .unavailable
            messages = [
                GoalChatMessage(
                    role: .assistant,
                    text: "Grok is unavailable right now. You can still define goals with a form."
                )
            ]
        }
    }

    // MARK: - Chat actions

    func sendDraft() {
        let text = draftInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(GoalChatMessage(role: .user, text: text))
        draftInput = ""
        errorMessage = nil
        handleAnalysis(of: text)
    }

    func useFormPath() {
        editingGoalID = nil
        formDraft = GoalFormDraft.blank(remainingShare: remainingShareFraction())
        phase = .form
    }

    func confirmProposals() {
        guard !proposals.isEmpty else { return }
        definedGoals = GoalValidationService.goals(from: proposals, now: clock())
        proposals = []
        phase = .goalsDefined
        messages.append(
            GoalChatMessage(
                role: .assistant,
                text: "Goals confirmed. Adjust shares if needed, then Continue when they total 100%."
            )
        )
    }

    func editProposals() {
        // Open the first proposal in the form for editing (design: Edit on card).
        guard let first = proposals.first else {
            useFormPath()
            return
        }
        editingGoalID = first.id
        formDraft = GoalFormDraft(from: first, now: clock())
        // Keep remaining proposals context; user may save one at a time.
        phase = .form
    }

    func editDefinedGoal(_ goal: Goal) {
        editingGoalID = goal.id
        formDraft = GoalFormDraft(from: goal)
        phase = .form
    }

    func cancelForm() {
        formDraft = GoalFormDraft()
        editingGoalID = nil
        if !definedGoals.isEmpty {
            phase = .goalsDefined
        } else if !proposals.isEmpty {
            phase = .proposal
        } else if phase == .unavailable || followUpCount >= GoalValidationService.maxFollowUps {
            phase = followUpCount > 0 ? .followUp : .chat
            if case .failure(.unavailable) = grok.analyzeGoalInput("car") {
                phase = .unavailable
            }
        } else {
            phase = .chat
        }
    }

    @discardableResult
    func saveForm() -> Bool {
        guard formDraft.canSave else { return false }
        let goal = formDraft.makeGoal(id: editingGoalID ?? UUID(), now: clock())
        if let editingGoalID,
           let index = definedGoals.firstIndex(where: { $0.id == editingGoalID }) {
            definedGoals[index] = goal
        } else if let editingGoalID,
                  proposals.contains(where: { $0.id == editingGoalID }) {
            // Replacing a proposal edit: fold into defined goals (confirm path).
            var next = GoalValidationService.goals(from: proposals, now: clock())
            if let idx = next.firstIndex(where: { $0.id == editingGoalID }) {
                next[idx] = goal
            } else {
                next.append(goal)
            }
            definedGoals = next
            proposals = []
        } else {
            definedGoals.append(goal)
        }
        editingGoalID = nil
        formDraft = GoalFormDraft()
        phase = .goalsDefined
        return true
    }

    func updateShare(for goalID: UUID, displayPercent: Int) {
        guard let index = definedGoals.firstIndex(where: { $0.id == goalID }) else { return }
        let clamped = min(max(displayPercent, 0), 100)
        definedGoals[index].shareOfNewCredits = Decimal(clamped) / 100
    }

    func continueToOpeningSplit() {
        guard canContinue else { return }
        shouldNavigateToOpeningSplit = true
    }

    func formatINR(paisa: Paisa) -> String {
        formatting.formatINR(paisa: paisa)
    }

    // MARK: - Private

    private func handleAnalysis(of text: String) {
        switch grok.analyzeGoalInput(text) {
        case .failure(.unavailable):
            phase = .unavailable
            messages.append(
                GoalChatMessage(
                    role: .assistant,
                    text: "Grok is unavailable. Use a form to add your goals."
                )
            )
        case .failure:
            presentFollowUpOrForm(preferredQuestion: StubGrokService.followUpQuestions[0])
        case .success(.proposals(let list)):
            proposals = list
            phase = .proposal
            messages.append(
                GoalChatMessage(
                    role: .assistant,
                    text: "Here’s a suggested plan. Edit or Confirm when you’re ready."
                )
            )
        case .success(.needsClarification(let question)):
            presentFollowUpOrForm(preferredQuestion: question)
        }
    }

    private func presentFollowUpOrForm(preferredQuestion: String) {
        if followUpCount >= GoalValidationService.maxFollowUps {
            messages.append(
                GoalChatMessage(
                    role: .assistant,
                    text: "Let’s use the form so you can enter goals precisely."
                )
            )
            useFormPath()
            return
        }
        let question = StubGrokService.followUpQuestion(at: followUpCount)
        // Prefer stub sequence; fall back to service question if needed.
        followUpPrompt = followUpCount < StubGrokService.followUpQuestions.count
            ? question
            : preferredQuestion
        followUpCount += 1
        phase = .followUp
        messages.append(
            GoalChatMessage(role: .assistant, text: followUpPrompt ?? preferredQuestion)
        )
    }

    private func remainingShareFraction() -> Decimal {
        let used = definedGoals.map(\.shareOfNewCredits).reduce(Decimal(0), +)
        let remaining = Decimal(1) - used
        return remaining > 0 ? remaining : Decimal(string: "0.5")!
    }
}

// MARK: - Form draft

/// Editable Goal form state (frame 6) with live inflation math.
struct GoalFormDraft: Equatable, Sendable {
    var name: String = ""
    /// Digit-only rupee string for the target field.
    var targetRupeeDigits: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(86_400 * 365)
    var inflationRate: Decimal = GoalValidationService.defaultInflationRate
    /// Share of new credits 0.0–1.0
    var shareOfNewCredits: Decimal = Decimal(string: "0.5")!
    /// Create path locks saved at ₹0.
    var savedAmount: Paisa = 0

    var targetPaisa: Paisa {
        GoalValidationService.paisa(fromRupeeDigits: targetRupeeDigits)
    }

    var canSave: Bool {
        GoalValidationService.canSave(
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate
        )
    }

    var adjustedTargetPaisa: Paisa {
        GoalValidationService.adjustedTargetPaisa(
            targetPaisa: targetPaisa,
            inflationRate: inflationRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    var monthlyNeedPaisa: Paisa {
        GoalValidationService.monthlyNeedPaisa(
            adjustedTarget: adjustedTargetPaisa,
            savedAmount: savedAmount,
            endDate: endDate
        )
    }

    var inflationPercentDisplay: Int {
        GoalValidationService.displayPercent(fromFraction: inflationRate)
    }

    var sharePercentDisplay: Int {
        GoalValidationService.displayPercent(fromFraction: shareOfNewCredits)
    }

    static func blank(remainingShare: Decimal, now: Date = Date()) -> GoalFormDraft {
        var draft = GoalFormDraft()
        draft.startDate = now
        draft.endDate = now.addingTimeInterval(86_400 * 365)
        draft.shareOfNewCredits = remainingShare
        draft.inflationRate = GoalValidationService.defaultInflationRate
        return draft
    }

    init() {}

    init(from proposal: GoalProposal, now: Date = Date()) {
        name = proposal.name
        if let target = proposal.suggestedTarget {
            targetRupeeDigits = String(target / 100)
        }
        startDate = now
        endDate = now.addingTimeInterval(86_400 * 365)
        inflationRate = GoalValidationService.defaultInflationRate
        shareOfNewCredits = proposal.sharePercentage
        savedAmount = 0
    }

    init(from goal: Goal) {
        name = goal.name
        targetRupeeDigits = String(goal.targetAmount / 100)
        startDate = goal.startDate
        endDate = goal.endDate
        inflationRate = goal.inflationRate
        shareOfNewCredits = goal.shareOfNewCredits
        savedAmount = goal.savedAmount
    }

    func makeGoal(id: UUID, now: Date = Date()) -> Goal {
        GoalValidationService.makeGoal(
            id: id,
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate,
            inflationRate: inflationRate,
            shareOfNewCredits: shareOfNewCredits,
            savedAmount: savedAmount,
            now: now
        )
    }
}
