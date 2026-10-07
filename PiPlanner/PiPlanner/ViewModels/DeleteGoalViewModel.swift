import Combine
import Foundation

/// View model for Delete goal flow (frames 17 / 17a–17e) — PRD R13, Spec BR-9.
@MainActor
final class DeleteGoalViewModel: ObservableObject {
    @Published private(set) var phase: DeleteGoalService.Phase
    @Published private(set) var goals: [Goal]
    @Published private(set) var displayPercents: [UUID: Int]
    /// After the user finishes one edit pass, percentages lock until confirm.
    @Published private(set) var hasEditedOnce = false
    @Published private(set) var standingResetToEqual = false
    @Published private(set) var isConfirming = false
    @Published var showConfirmDialog = false
    @Published var showCreateSheet = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didDelete = false

    /// Draft fields for mid-delete create (17d / 17e).
    @Published var replacementName = ""
    @Published var replacementTargetRupees = ""

    let deletingGoal: Goal
    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID
    private let onDeleted: (() -> Void)?

    init(
        goal: Goal,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        onDeleted: (() -> Void)? = nil
    ) {
        self.deletingGoal = goal
        self.goals = goals
        self.persistence = persistence
        self.formatting = formatting
        self.clock = clock
        self.makeID = makeID
        self.onDeleted = onDeleted

        let remaining = DeleteGoalService.remainingGoals(deletingGoalID: goal.id, from: goals)
        self.phase = DeleteGoalService.initialPhase(deletingGoalID: goal.id, goals: goals)
        self.displayPercents = DeleteGoalService.equalReassignmentDisplayPercents(remaining: remaining)
    }

    var remainingGoals: [Goal] {
        DeleteGoalService.remainingGoals(deletingGoalID: deletingGoal.id, from: goals)
    }

    var formattedReleasedAmount: String {
        formatting.formatINR(paisa: deletingGoal.savedAmount)
    }

    var fractionMap: [UUID: Decimal] {
        Dictionary(uniqueKeysWithValues: remainingGoals.map { goal in
            (goal.id, Decimal(displayPercents[goal.id] ?? 0) / 100)
        })
    }

    var orderedFractions: [Decimal] {
        remainingGoals.map { fractionMap[$0.id] ?? 0 }
    }

    var canConfirm: Bool {
        !isConfirming
            && DeleteGoalService.canConfirm(
                deletingGoalID: deletingGoal.id,
                goals: goals,
                percentages: fractionMap
            )
    }

    var isEditing: Bool { phase == .reassignEdit }

    var canStartEdit: Bool {
        !hasEditedOnce
            && (phase == .reassignDefault || phase == .confirm)
            && remainingGoals.count > 1
    }

    var statusMessage: String {
        switch phase {
        case .onlyGoalGate:
            return DeleteGoalService.onlyGoalGateMessage
        case .reassignDefault, .reassignEdit, .confirm:
            if remainingGoals.count == 1 {
                return "100% will move to \(remainingGoals[0].name)."
            }
            return OpeningSplitService.shortfallMessage(for: orderedFractions)
                ?? (hasEditedOnce
                    ? "Total 100%. Ready to confirm."
                    : "Total 100%. Edit once or confirm.")
        }
    }

    func formattedAmount(for goalID: UUID) -> String {
        formatting.formatINR(paisa: amount(for: goalID))
    }

    func amount(for goalID: UUID) -> Paisa {
        let amounts = OpeningSplitService.allocatePaisa(
            total: max(deletingGoal.savedAmount, 0),
            fractions: orderedFractions
        )
        guard let index = remainingGoals.firstIndex(where: { $0.id == goalID }) else { return 0 }
        return amounts[index]
    }

    func beginEdit() {
        guard canStartEdit else { return }
        phase = .reassignEdit
        errorMessage = nil
    }

    func finishEdit() {
        guard phase == .reassignEdit else { return }
        guard OpeningSplitService.isValidHundredPercent(orderedFractions) else {
            errorMessage = OpeningSplitService.shortfallMessage(for: orderedFractions)
            return
        }
        hasEditedOnce = true
        phase = .confirm
        errorMessage = nil
    }

    func setDisplayPercent(goalID: UUID, percent: Int) {
        guard phase == .reassignEdit, !hasEditedOnce else { return }
        displayPercents[goalID] = min(max(percent, 0), 100)
        errorMessage = nil
    }

    func requestConfirm() {
        guard canConfirm else { return }
        if phase == .reassignEdit {
            // Treat confirm from edit as finishing the one edit pass.
            guard OpeningSplitService.isValidHundredPercent(orderedFractions) else {
                errorMessage = OpeningSplitService.shortfallMessage(for: orderedFractions)
                return
            }
            hasEditedOnce = true
        }
        phase = .confirm
        showConfirmDialog = true
    }

    func openCreateReplacement() {
        replacementName = ""
        replacementTargetRupees = ""
        showCreateSheet = true
    }

    /// Creates a replacement / additional goal mid-delete (17d / 17e). Resets standing to equal.
    func createReplacementGoal() async {
        let trimmed = replacementName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a goal name."
            return
        }
        let digits = replacementTargetRupees.filter(\.isNumber)
        guard let rupees = Paisa(digits), rupees > 0 else {
            errorMessage = "Enter a target greater than ₹0."
            return
        }

        let now = clock()
        let goal = GoalValidationService.makeGoal(
            id: makeID(),
            name: trimmed,
            targetPaisa: rupees * 100,
            startDate: now,
            endDate: now.addingTimeInterval(86_400 * 365),
            shareOfNewCredits: 0,
            savedAmount: 0,
            now: now
        )

        do {
            var state = try await persistence.loadState()
            // Ensure the deleting goal's cohort is present.
            if state.goals.isEmpty {
                state.goals = goals
            }
            state = DeleteGoalService.addGoalDuringDelete(
                to: state,
                goal: goal,
                resetStandingToEqual: true,
                now: now
            )
            try await persistence.saveState(state)
            goals = state.goals
            standingResetToEqual = true
            hasEditedOnce = false
            displayPercents = DeleteGoalService.equalReassignmentDisplayPercents(
                remaining: remainingGoals
            )
            phase = .reassignDefault
            showCreateSheet = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmDelete() async {
        guard canConfirm else { return }
        isConfirming = true
        errorMessage = nil
        defer { isConfirming = false }

        do {
            var state = try await persistence.loadState()
            if state.goals.isEmpty {
                state.goals = goals
            } else {
                // Mid-delete creates are persisted in createReplacementGoal; merge any missing.
                for goal in goals where !state.goals.contains(where: { $0.id == goal.id }) {
                    state.goals.append(goal)
                }
            }

            state = try DeleteGoalService.applyDeletion(
                to: state,
                deletingGoalID: deletingGoal.id,
                percentages: fractionMap,
                resetStandingToEqual: standingResetToEqual,
                entryID: makeID(),
                now: clock()
            )
            try await persistence.saveState(state)
            goals = state.goals
            didDelete = true
            showConfirmDialog = false
            onDeleted?()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
