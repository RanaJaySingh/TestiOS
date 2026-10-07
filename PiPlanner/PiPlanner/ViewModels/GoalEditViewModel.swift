import Combine
import Foundation

/// View model for Goal edit (frame 6e) — PRD R11 / R24, Spec BR-4.
@MainActor
final class GoalEditViewModel: ObservableObject {
    @Published var draft: GoalEditDraft
    @Published var showInflationPopup = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSave = false
    @Published private(set) var lastCommit: GoalEditCommitResult?

    let goal: Goal
    private let history: [HistoryEntry]
    private let heldChanges: [HeldGoalChange]
    private let standingSplits: [StandingSplit]
    private let persistence: (any PersistenceServicing)?
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID

    init(
        goal: Goal,
        history: [HistoryEntry] = [],
        heldChanges: [HeldGoalChange] = [],
        standingSplits: [StandingSplit] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService(),
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.goal = goal
        self.draft = GoalEditDraft(goal: goal)
        self.history = history
        self.heldChanges = heldChanges
        self.standingSplits = standingSplits
        self.persistence = persistence
        self.formatting = formatting
        self.clock = clock
        self.makeID = makeID
    }

    var canSave: Bool {
        draft.canSave && !isSaving
    }

    /// Saved amount is always the live goal value (locked on edit).
    var lockedSavedAmount: Paisa {
        goal.savedAmount
    }

    func formatINR(paisa: Paisa) -> String {
        formatting.formatINR(paisa: paisa)
    }

    /// Saves held edit: updates goal params for next credit; does not rewrite History.
    @discardableResult
    func save() async -> GoalEditCommitResult? {
        guard draft.canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let result = GoalHeldChangeService.commitEdit(
            goal: goal,
            draft: draft,
            history: history,
            heldChanges: heldChanges,
            standingSplits: standingSplits,
            now: clock(),
            changeID: makeID()
        )

        if let persistence {
            do {
                var state = try await persistence.loadState()
                if let index = state.goals.firstIndex(where: { $0.id == goal.id }) {
                    state.goals[index] = result.updatedGoal
                } else {
                    state.goals.append(result.updatedGoal)
                }
                // History must remain byte-identical for locked entries (BR-3 / BR-4).
                state.history = result.history
                state.heldGoalChanges = result.heldChanges
                state.standingSplits = result.updatedStandingSplits
                try await persistence.saveState(state)
            } catch {
                errorMessage = error.localizedDescription
                return nil
            }
        }

        lastCommit = result
        didSave = true
        return result
    }
}
