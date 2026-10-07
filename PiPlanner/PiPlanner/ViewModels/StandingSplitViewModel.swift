import Combine
import Foundation

/// View model for Standing split (frame 15) — PRD R12, Spec BR-2 / BR-4.
@MainActor
final class StandingSplitViewModel: ObservableObject {
    /// Whole-number display percents keyed by goal id (0…100).
    @Published private(set) var displayPercents: [UUID: Int]
    @Published private(set) var isSaving = false
    @Published private(set) var didSave = false
    @Published private(set) var errorMessage: String?
    /// Set after a successful save so the view can dismiss.
    @Published private(set) var shouldDismiss = false
    /// One-goal skip path: editor not shown; 100% applied automatically when presented.
    @Published private(set) var didAutoSkip = false

    let goals: [Goal]
    private let persistence: any PersistenceServicing
    private let clock: () -> Date

    var isSingleGoal: Bool { goals.count == 1 }
    var shouldPresentEditor: Bool { StandingSplitService.shouldPresentEditor(goalCount: goals.count) }

    var fractionMap: [UUID: Decimal] {
        if isSingleGoal, let goal = goals.first {
            return StandingSplitService.singleGoalPercentages(goalID: goal.id)
        }
        return Dictionary(uniqueKeysWithValues: goals.map { goal in
            let percent = displayPercents[goal.id] ?? 0
            return (goal.id, Decimal(percent) / 100)
        })
    }

    var orderedFractions: [Decimal] {
        goals.map { fractionMap[$0.id] ?? 0 }
    }

    var totalDisplayPercent: Decimal {
        StandingSplitService.totalDisplayPercent(orderedFractions)
    }

    var canSave: Bool {
        !isSaving
            && shouldPresentEditor
            && StandingSplitService.isValidHundredPercent(orderedFractions)
    }

    var isValidTotal: Bool {
        StandingSplitService.isValidHundredPercent(orderedFractions)
    }

    var statusMessage: String {
        if didSave {
            return StandingSplitService.changeAppliesNextCreditMessage
        }
        if isSingleGoal {
            return "One goal — standing split is 100% automatic."
        }
        return StandingSplitService.shortfallMessage(for: orderedFractions)
            ?? "Total 100%. Ready to save."
    }

    init(
        goals: [Goal],
        persistence: any PersistenceServicing,
        standingSplits: [StandingSplit] = [],
        initialPercents: [UUID: Int]? = nil,
        clock: @escaping () -> Date = Date.init
    ) {
        self.goals = goals
        self.persistence = persistence
        self.clock = clock

        if let initialPercents {
            self.displayPercents = Dictionary(uniqueKeysWithValues: goals.map { goal in
                (goal.id, initialPercents[goal.id] ?? 0)
            })
        } else {
            self.displayPercents = StandingSplitService.initialDisplayPercents(
                for: goals,
                standingSplits: standingSplits
            )
        }
    }

    func setDisplayPercent(goalID: UUID, percent: Int) {
        guard shouldPresentEditor else { return }
        let clamped = min(max(percent, 0), 100)
        displayPercents[goalID] = clamped
        errorMessage = nil
        didSave = false
    }

    /// One-goal skip: persist 100% without showing an editable editor (R12).
    /// Does not auto-dismiss — the skip confirmation stays visible until the user leaves.
    func applySingleGoalSkipIfNeeded() async {
        guard isSingleGoal, !didAutoSkip else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state = try await persistence.loadState()
            if state.goals.isEmpty {
                state.goals = goals
            }
            state = try StandingSplitService.applySingleGoalSkip(to: state, now: clock())
            try await persistence.saveState(state)
            didAutoSkip = true
            didSave = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves standing split for multi-goal edit when total is 100%.
    func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state = try await persistence.loadState()
            if state.goals.isEmpty {
                state.goals = goals
            }
            // Ensure goal order / ids match the screen being edited.
            let percentages = fractionMap
            state = try StandingSplitService.applyStandingSplit(
                to: state,
                percentages: percentages,
                now: clock()
            )
            try await persistence.saveState(state)
            didSave = true
            shouldDismiss = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
