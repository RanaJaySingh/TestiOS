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

    /// Saves held edit via `LedgerEngineCore.updateGoalPending` (PIP-105).
    /// Updates goal params for the next credit; does not rewrite History.
    @discardableResult
    func save() async -> GoalEditCommitResult? {
        guard draft.canSave else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state: PersistedAppState
            if let persistence {
                state = try await persistence.loadState()
            } else {
                // Preview / offline path — seed from local snapshots.
                state = PersistedAppState(
                    accounts: [],
                    goals: [goal],
                    history: history,
                    standingSplits: standingSplits,
                    heldGoalChanges: heldChanges
                )
            }

            let held = try GoalDetailStandingService.commitHeldEdit(
                to: state,
                goalID: goal.id,
                draft: draft,
                now: clock(),
                changeID: makeID()
            )

            if let persistence {
                try await persistence.saveState(held.state)
            }

            lastCommit = held.commit
            didSave = true
            return held.commit
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
