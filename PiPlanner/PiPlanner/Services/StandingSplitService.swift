import Foundation

/// Standing split validation and persistence helpers (PRD R12, Spec BR-2 / BR-4, frame 15).
///
/// Standing split sets default shares for the *next* credit. Saved amounts on goals are never
/// rewritten here ("Saved money stays put").
enum StandingSplitService {
    /// Frame 15 copy — edits do not move money already locked to goals.
    static let savedMoneyStaysPutMessage = "Saved money stays put"

    /// Spec BR-4 confirmation after a successful save.
    static let changeAppliesNextCreditMessage = "Change saved. Applies at the next credit."

    // MARK: - Presentation

    /// Multi-goal editor (frame 15) only when two or more goals exist.
    /// With one goal the UI is skipped and share is automatically 100%.
    static func shouldPresentEditor(goalCount: Int) -> Bool {
        goalCount >= 2
    }

    /// Single-goal: auto-assign 100% (R12 / frame 8b-style skip).
    static func singleGoalPercentages(goalID: UUID) -> [UUID: Decimal] {
        OpeningSplitService.singleGoalPercentages(goalID: goalID)
    }

    // MARK: - Validation (BR-2 / R12)

    static func isValidHundredPercent(_ fractions: [Decimal]) -> Bool {
        OpeningSplitService.isValidHundredPercent(fractions)
    }

    static func totalDisplayPercent(_ fractions: [Decimal]) -> Decimal {
        OpeningSplitService.totalDisplayPercent(fractions)
    }

    static func shortfallMessage(for fractions: [Decimal]) -> String? {
        OpeningSplitService.shortfallMessage(for: fractions)
    }

    // MARK: - Build / apply

    /// Builds ordered standing splits that sum to exactly 100%.
    static func makeStandingSplits(
        goals: [Goal],
        percentages: [UUID: Decimal]
    ) throws -> [StandingSplit] {
        guard !goals.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "At least one goal is required for standing split.",
                    code: .splitNotHundred
                )
            )
        }

        let orderedFractions = goals.map { percentages[$0.id] ?? 0 }
        guard isValidHundredPercent(orderedFractions) else {
            throw AppError.validationError(
                ValidationError(
                    field: "percentages",
                    message: shortfallMessage(for: orderedFractions)
                        ?? "Splits must total 100%.",
                    code: .splitNotHundred
                )
            )
        }

        return zip(goals, orderedFractions).map { goal, fraction in
            StandingSplit(goalId: goal.id, percentage: fraction.rounded(scale: 4))
        }
    }

    /// Persists standing split: updates `standingSplits` + each goal's `shareOfNewCredits`.
    /// Does **not** change `savedAmount` (R12 / BR-4).
    static func applyStandingSplit(
        to state: PersistedAppState,
        percentages: [UUID: Decimal],
        now: Date = Date()
    ) throws -> PersistedAppState {
        let splits = try makeStandingSplits(goals: state.goals, percentages: percentages)
        let byID = Dictionary(uniqueKeysWithValues: splits.map { ($0.goalId, $0.percentage) })

        var next = state
        next.standingSplits = splits
        next.goals = next.goals.map { goal in
            var updated = goal
            if let share = byID[goal.id] {
                updated.shareOfNewCredits = share
                updated.updatedAt = now
            }
            return updated
        }
        return next
    }

    /// Ensures a lone goal is at 100% standing share (skip path).
    static func applySingleGoalSkip(
        to state: PersistedAppState,
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard state.goals.count == 1, let goal = state.goals.first else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "Single-goal skip requires exactly one goal.",
                    code: .splitNotHundred
                )
            )
        }
        return try applyStandingSplit(
            to: state,
            percentages: singleGoalPercentages(goalID: goal.id),
            now: now
        )
    }

    // MARK: - Next credit (contract for PIP-47)

    /// Resolves default split percentages for the next credit assignment.
    /// Prefers persisted `standingSplits`; falls back to each goal's `shareOfNewCredits`.
    static func percentagesForNextCredit(from state: PersistedAppState) -> [UUID: Decimal] {
        let goals = state.goals
        guard !goals.isEmpty else { return [:] }

        if goals.count == 1, let goal = goals.first {
            return singleGoalPercentages(goalID: goal.id)
        }

        let fromStanding = Dictionary(
            uniqueKeysWithValues: state.standingSplits.map { ($0.goalId, $0.percentage) }
        )
        let orderedFromStanding = goals.map { fromStanding[$0.id] ?? 0 }
        if isValidHundredPercent(orderedFromStanding) {
            return Dictionary(uniqueKeysWithValues: goals.map { goal in
                (goal.id, fromStanding[goal.id] ?? 0)
            })
        }

        return Dictionary(uniqueKeysWithValues: goals.map { goal in
            (goal.id, goal.shareOfNewCredits)
        })
    }

    /// Initial display percents (0…100) from standing splits / goal shares, else equal split.
    static func initialDisplayPercents(for goals: [Goal], standingSplits: [StandingSplit]) -> [UUID: Int] {
        guard !goals.isEmpty else { return [:] }
        if goals.count == 1, let goal = goals.first {
            return [goal.id: 100]
        }

        let fromStanding = Dictionary(
            uniqueKeysWithValues: standingSplits.map { ($0.goalId, $0.percentage) }
        )
        let fromShares = goals.map { goal -> (UUID, Int) in
            let fraction = fromStanding[goal.id] ?? goal.shareOfNewCredits
            return (goal.id, fraction.roundedTowardZeroDisplayPercent)
        }
        let shareTotal = fromShares.reduce(0) { $0 + $1.1 }
        if shareTotal == 100 {
            return Dictionary(uniqueKeysWithValues: fromShares)
        }
        return equalDisplayPercents(for: goals)
    }

    static func equalDisplayPercents(for goals: [Goal]) -> [UUID: Int] {
        guard !goals.isEmpty else { return [:] }
        let base = 100 / goals.count
        var remainder = 100 - (base * goals.count)
        var result: [UUID: Int] = [:]
        for goal in goals {
            let extra = remainder > 0 ? 1 : 0
            if remainder > 0 { remainder -= 1 }
            result[goal.id] = base + extra
        }
        return result
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }

    var roundedTowardZeroDisplayPercent: Int {
        NSDecimalNumber(decimal: self * 100).intValue
    }
}
