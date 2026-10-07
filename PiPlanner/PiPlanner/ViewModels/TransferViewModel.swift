import Combine
import Foundation

/// View model for Transfer between goals (frames 16 / 16a–16c) — PRD R14, Spec BR-7.
@MainActor
final class TransferViewModel: ObservableObject {
    @Published var fromGoalId: UUID?
    @Published var toGoalId: UUID?
    /// Rupee amount as typed / chip-filled digits (UI shows rupees; store paisa).
    @Published var amountRupeesText: String = ""
    @Published private(set) var goals: [Goal]
    @Published private(set) var standingSplitsSnapshot: [StandingSplit]
    @Published private(set) var isMoving = false
    @Published private(set) var didComplete = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var completionMessage: String?

    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID
    private let onCompleted: (() -> Void)?

    init(
        goals: [Goal],
        standingSplits: [StandingSplit] = [],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        prefill: TransferService.Prefill? = nil,
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        onCompleted: (() -> Void)? = nil
    ) {
        self.goals = goals
        self.standingSplitsSnapshot = standingSplits
        self.persistence = persistence
        self.formatting = formatting
        self.clock = clock
        self.makeID = makeID
        self.onCompleted = onCompleted

        if let prefill {
            applyPrefill(prefill)
        } else if goals.count >= 2 {
            // Sensible default From = first goal with savings, To = next.
            fromGoalId = goals.first(where: { $0.savedAmount > 0 })?.id ?? goals[0].id
            toGoalId = TransferService.toCandidates(fromGoalId: fromGoalId, goals: goals).first?.id
        }
    }

    // MARK: - Derived

    var amountPaisa: Paisa {
        TransferService.parseAmountPaisa(fromRupeesText: amountRupeesText)
    }

    var fromGoal: Goal? {
        TransferService.goal(id: fromGoalId, in: goals)
    }

    var toGoal: Goal? {
        TransferService.goal(id: toGoalId, in: goals)
    }

    var toCandidates: [Goal] {
        TransferService.toCandidates(fromGoalId: fromGoalId, goals: goals)
    }

    var phase: TransferService.Phase {
        TransferService.resolvePhase(
            fromGoalId: fromGoalId,
            toGoalId: toGoalId,
            amountPaisa: amountPaisa,
            goals: goals,
            isComplete: didComplete
        )
    }

    var preview: TransferService.BalancePreview? {
        TransferService.preview(
            fromGoalId: fromGoalId,
            toGoalId: toGoalId,
            amountPaisa: amountPaisa,
            goals: goals
        )
    }

    var canMove: Bool {
        TransferService.canMove(
            fromGoalId: fromGoalId,
            toGoalId: toGoalId,
            amountPaisa: amountPaisa,
            goals: goals,
            isMoving: isMoving,
            isComplete: didComplete
        )
    }

    var statusMessage: String {
        switch phase {
        case .select:
            return "Choose From and To goals."
        case .enterAmount:
            return "Enter an amount or tap a chip."
        case .preview:
            return "After transfer preview ready. Tap Move to confirm."
        case .overAmount:
            return TransferService.overAmountMessage
        case .complete:
            return completionMessage ?? "Transfer complete."
        }
    }

    var chipRupees: [Paisa] { TransferService.chipRupees }

    func formattedSaved(for goal: Goal) -> String {
        formatting.formatINR(paisa: goal.savedAmount)
    }

    func formattedPaisa(_ paisa: Paisa) -> String {
        formatting.formatINR(paisa: paisa)
    }

    // MARK: - Intents

    func applyPrefill(_ prefill: TransferService.Prefill) {
        if let from = prefill.fromGoalId, goals.contains(where: { $0.id == from }) {
            fromGoalId = from
        }
        if let to = prefill.toGoalId, goals.contains(where: { $0.id == to }) {
            toGoalId = to
        }
        if let amount = prefill.amountPaisa, amount > 0 {
            amountRupeesText = String(amount / 100)
        }
        // Keep To ≠ From.
        if fromGoalId == toGoalId {
            toGoalId = TransferService.toCandidates(fromGoalId: fromGoalId, goals: goals).first?.id
        }
        errorMessage = nil
        didComplete = false
    }

    func selectFrom(_ id: UUID) {
        fromGoalId = id
        if toGoalId == id {
            toGoalId = TransferService.toCandidates(fromGoalId: id, goals: goals).first?.id
        }
        errorMessage = nil
        didComplete = false
    }

    func selectTo(_ id: UUID) {
        guard id != fromGoalId else { return }
        toGoalId = id
        errorMessage = nil
        didComplete = false
    }

    func applyChip(rupees: Paisa) {
        amountRupeesText = String(rupees)
        errorMessage = nil
        didComplete = false
    }

    func setAmountRupeesText(_ text: String) {
        amountRupeesText = text.filter { $0.isNumber || $0 == "," }
        // Normalize to digits-only storage for parsing consistency.
        let digits = amountRupeesText.filter(\.isNumber)
        amountRupeesText = digits
        errorMessage = nil
        didComplete = false
    }

    func confirmMove() async {
        // Defense in depth: Complete is terminal — never apply twice.
        guard !didComplete else { return }
        guard canMove,
              let fromID = fromGoalId,
              let toID = toGoalId
        else { return }

        isMoving = true
        errorMessage = nil
        defer { isMoving = false }

        do {
            var state = try await persistence.loadState()
            if state.goals.isEmpty {
                state.goals = goals
                state.standingSplits = standingSplitsSnapshot
            }

            // PIP-106: Transfer sheet → History via LedgerEngineCore (append-only locked entry).
            state = try LedgerEngineCore.transfer(
                to: state,
                fromGoalId: fromID,
                toGoalId: toID,
                amountPaisa: amountPaisa,
                entryID: makeID(),
                now: clock()
            )

            try await persistence.saveState(state)
            goals = state.goals
            standingSplitsSnapshot = state.standingSplits

            if let from = state.goals.first(where: { $0.id == fromID }),
               let to = state.goals.first(where: { $0.id == toID }) {
                completionMessage = TransferService.historyTitle(
                    fromName: from.name,
                    toName: to.name,
                    amountPaisa: amountPaisa,
                    formatting: formatting
                )
            } else {
                completionMessage = "Transfer complete."
            }
            didComplete = true
            onCompleted?()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reload goals after external edits.
    func refreshGoals() async {
        do {
            let state = try await persistence.loadState()
            if !state.goals.isEmpty {
                goals = state.goals
                standingSplitsSnapshot = state.standingSplits
            }
        } catch {
            // Non-fatal for UI; keep current list.
        }
    }
}
