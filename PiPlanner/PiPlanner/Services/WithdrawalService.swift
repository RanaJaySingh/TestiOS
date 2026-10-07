import Foundation

/// Withdrawal proportional allocation + History lock (PRD R15, Spec BR-8 / BR-2).
/// Pure / Linux-testable. Reductions are paisa (`Int64`); standing split is not redefined.
enum WithdrawalService {
    /// UI / flow phases for frames 18 / 18a / 18b / 18c.
    enum Phase: String, Equatable, Sendable {
        case proportionalDefault
        case edit
        case invalidTotal
        case goalBelowZero
        case complete
    }

    /// History row copy for a locked withdrawal entry (AC / PRD R15).
    static let historyTitle = "Withdrawal"

    /// Caption under withdrawal (frame 18).
    static let proportionalCaption =
        "Assign this shortfall across goals, proportional to current savings. You can edit once before Save and lock."

    /// Caption when recording manually (frame 18c).
    static let manualRecordCaption =
        "Record a withdrawal when the dedicated balance went down. Reductions default to proportional savings."

    // MARK: - Proportional default (BR-8)

    /// Fractions of total saved (0.0–1.0) used as the proportional default.
    /// Goals with zero saved receive 0. When all saved amounts are 0, falls back to equal shares.
    static func proportionalFractions(goals: [Goal]) -> [UUID: Decimal] {
        guard !goals.isEmpty else { return [:] }
        let totalSaved = goals.map(\.savedAmount).reduce(Paisa(0), +)
        if totalSaved <= 0 {
            let equal = Decimal(1) / Decimal(goals.count)
            return Dictionary(uniqueKeysWithValues: goals.map { ($0.id, equal.rounded(scale: 4)) })
        }
        var result: [UUID: Decimal] = [:]
        result.reserveCapacity(goals.count)
        for goal in goals {
            let fraction = Decimal(goal.savedAmount) / Decimal(totalSaved)
            result[goal.id] = fraction.rounded(scale: 4)
        }
        // Renormalize to exact 1.0 after rounding using largest-remainder on basis points.
        let orderedIDs = goals.map(\.id)
        let fractions = orderedIDs.map { result[$0] ?? 0 }
        let sum = fractions.reduce(Decimal(0), +)
        if sum != 1, sum > 0 {
            let scale = Decimal(1) / sum
            for id in orderedIDs {
                result[id] = ((result[id] ?? 0) * scale).rounded(scale: 4)
            }
            // Fix residual on last goal so fractions sum to 1.
            let renormalized = orderedIDs.map { result[$0] ?? 0 }
            let residual = Decimal(1) - renormalized.dropLast().reduce(Decimal(0), +)
            if let last = orderedIDs.last {
                result[last] = residual.rounded(scale: 4)
            }
        }
        return result
    }

    /// Display percents (0…100) for the proportional default.
    static func proportionalDisplayPercents(goals: [Goal]) -> [UUID: Int] {
        let fractions = proportionalFractions(goals: goals)
        let ordered = goals.map(\.id)
        guard !ordered.isEmpty else { return [:] }
        // Largest-remainder so integers sum to 100.
        var floors: [UUID: Int] = [:]
        var remainders: [(UUID, Double)] = []
        for id in ordered {
            let exact = NSDecimalNumber(decimal: (fractions[id] ?? 0) * 100).doubleValue
            let floorValue = Int(exact.rounded(.towardZero))
            floors[id] = floorValue
            remainders.append((id, exact - Double(floorValue)))
        }
        var leftover = 100 - floors.values.reduce(0, +)
        for (id, _) in remainders.sorted(by: { $0.1 > $1.1 }) where leftover > 0 {
            floors[id, default: 0] += 1
            leftover -= 1
        }
        return floors
    }

    /// Default reduction amounts (paisa) proportional to current savings; sums exactly to `shortfall`.
    static func proportionalReductions(goals: [Goal], shortfall: Paisa) -> [UUID: Paisa] {
        guard !goals.isEmpty else { return [:] }
        let fractions = goals.map { proportionalFractions(goals: goals)[$0.id] ?? 0 }
        let amounts = OpeningSplitService.allocatePaisa(total: max(shortfall, 0), fractions: fractions)
        return Dictionary(uniqueKeysWithValues: zip(goals.map(\.id), amounts))
    }

    // MARK: - Validation

    /// Sum of reduction amounts.
    static func totalReductions(_ reductions: [UUID: Paisa], goals: [Goal]) -> Paisa {
        goals.map { reductions[$0.id] ?? 0 }.reduce(0, +)
    }

    /// True when every reduction is within 0…savedAmount (no goal below ₹0).
    static func allReductionsWithinSaved(reductions: [UUID: Paisa], goals: [Goal]) -> Bool {
        for goal in goals {
            let amount = reductions[goal.id] ?? 0
            if amount < 0 || amount > goal.savedAmount {
                return false
            }
        }
        return true
    }

    /// First goal that would go below ₹0, if any.
    static func firstGoalBelowZero(reductions: [UUID: Paisa], goals: [Goal]) -> Goal? {
        goals.first { goal in
            let amount = reductions[goal.id] ?? 0
            return amount < 0 || amount > goal.savedAmount
        }
    }

    /// Running-total copy when reductions ≠ shortfall (frame 18a).
    static func invalidTotalMessage(
        totalAssigned: Paisa,
        shortfall: Paisa,
        formatting: any FormattingServicing = FormattingService()
    ) -> String? {
        guard totalAssigned != shortfall else { return nil }
        let totalText = formatting.formatINR(paisa: totalAssigned)
        let shortfallText = formatting.formatINR(paisa: shortfall)
        if totalAssigned < shortfall {
            let remaining = formatting.formatINR(paisa: shortfall - totalAssigned)
            return "Total \(totalText). Assign the remaining \(remaining) (shortfall \(shortfallText))."
        }
        let over = formatting.formatINR(paisa: totalAssigned - shortfall)
        return "Total \(totalText). Reduce by \(over) (shortfall \(shortfallText))."
    }

    /// Copy when a reduction would make a goal < ₹0.
    static func goalBelowZeroMessage(goal: Goal) -> String {
        "\(goal.name) can’t go below ₹0. Reduce that withdrawal amount."
    }

    /// Save enabled when total == shortfall and no goal below ₹0.
    static func canSave(
        reductions: [UUID: Paisa],
        goals: [Goal],
        shortfall: Paisa
    ) -> Bool {
        guard shortfall > 0, !goals.isEmpty else { return false }
        guard totalReductions(reductions, goals: goals) == shortfall else { return false }
        return allReductionsWithinSaved(reductions: reductions, goals: goals)
    }

    /// Outcome of Done on the one edit pass (mirrors DeleteGoal `finishEdit` gating).
    /// Invalid totals must **not** complete the edit pass — caller must not set `hasEditedOnce`.
    struct FinishEditEvaluation: Equatable, Sendable {
        /// When true, lock edit-once and leave edit mode so Save can enable.
        var shouldCompleteEditPass: Bool
        /// Phase to apply. Refused Done → `.invalidTotal` / `.goalBelowZero` so `canStartEdit` stays true.
        var nextPhase: Phase
        var errorMessage: String?
    }

    /// Pure Done-gate for edit-once (PRD R15 / DeleteGoal parity).
    static func evaluateFinishEdit(
        reductions: [UUID: Paisa],
        goals: [Goal],
        shortfall: Paisa,
        formatting: any FormattingServicing = FormattingService()
    ) -> FinishEditEvaluation {
        if canSave(reductions: reductions, goals: goals, shortfall: shortfall) {
            return FinishEditEvaluation(
                shouldCompleteEditPass: true,
                nextPhase: .proportionalDefault,
                errorMessage: nil
            )
        }
        if let bad = firstGoalBelowZero(reductions: reductions, goals: goals) {
            return FinishEditEvaluation(
                shouldCompleteEditPass: false,
                nextPhase: .goalBelowZero,
                errorMessage: goalBelowZeroMessage(goal: bad)
            )
        }
        let total = totalReductions(reductions, goals: goals)
        return FinishEditEvaluation(
            shouldCompleteEditPass: false,
            nextPhase: .invalidTotal,
            errorMessage: invalidTotalMessage(
                totalAssigned: total,
                shortfall: shortfall,
                formatting: formatting
            ) ?? "Reductions must equal the shortfall."
        )
    }

    // MARK: - Allocations / History

    /// Builds per-goal allocations from absolute reduction amounts.
    static func makeAllocations(
        goals: [Goal],
        shortfall: Paisa,
        reductions: [UUID: Paisa]
    ) throws -> [GoalAllocation] {
        guard !goals.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "At least one goal is required for withdrawal.",
                    code: .splitNotHundred
                )
            )
        }
        guard shortfall > 0 else {
            throw AppError.validationError(
                ValidationError(
                    field: "shortfall",
                    message: "Withdrawal amount must be greater than ₹0.",
                    code: .amountExceedsSaved
                )
            )
        }

        let total = totalReductions(reductions, goals: goals)
        guard total == shortfall else {
            throw AppError.validationError(
                ValidationError(
                    field: "reductions",
                    message: invalidTotalMessage(totalAssigned: total, shortfall: shortfall)
                        ?? "Reductions must equal the shortfall.",
                    code: .splitNotHundred
                )
            )
        }

        if let bad = firstGoalBelowZero(reductions: reductions, goals: goals) {
            throw AppError.validationError(
                ValidationError(
                    field: "reductions",
                    message: goalBelowZeroMessage(goal: bad),
                    code: .goalBelowZero
                )
            )
        }

        return goals.map { goal in
            let amount = reductions[goal.id] ?? 0
            let percentage: Decimal
            if shortfall > 0 {
                percentage = (Decimal(amount) / Decimal(shortfall)).rounded(scale: 4)
            } else {
                percentage = 0
            }
            return GoalAllocation(
                goalId: goal.id,
                goalName: goal.name,
                amount: amount,
                percentage: percentage
            )
        }
    }

    /// Creates a locked Withdrawal History entry (frame 18b).
    static func createLockedWithdrawalEntry(
        goals: [Goal],
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        reductions: [UUID: Paisa],
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        guard newBalance == previousBalance - shortfall else {
            throw AppError.validationError(
                ValidationError(
                    field: "newBalance",
                    message: "New balance must equal previous balance minus shortfall.",
                    code: .amountExceedsSaved
                )
            )
        }
        let allocations = try makeAllocations(
            goals: goals,
            shortfall: shortfall,
            reductions: reductions
        )
        return HistoryEntry(
            id: id,
            type: .withdrawal,
            createdAt: createdAt,
            isLocked: true,
            previousBalance: previousBalance,
            newBalance: newBalance,
            creditAmount: nil,
            isTyped: nil,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: shortfall,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: allocations
        )
    }

    // MARK: - Apply

    /// Applies withdrawal: decrements goal saved amounts, sets dedicated balance, appends locked History.
    /// Standing split is unchanged (BR-8 / R15 — point-in-time reductions only).
    static func applyWithdrawal(
        to state: PersistedAppState,
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        reductions: [UUID: Paisa],
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard AccountsService.dedicatedAccount(in: state.accounts) != nil else {
            throw AppError.validationError(
                ValidationError(
                    field: "account",
                    message: "No dedicated savings account.",
                    code: .noDedicatedAccount
                )
            )
        }

        let entry = try createLockedWithdrawalEntry(
            goals: state.goals,
            shortfall: shortfall,
            previousBalance: previousBalance,
            newBalance: newBalance,
            reductions: reductions,
            id: entryID,
            createdAt: now
        )

        var next = state
        var goalsByID = Dictionary(uniqueKeysWithValues: next.goals.map { ($0.id, $0) })

        for allocation in entry.allocations {
            guard var goal = goalsByID[allocation.goalId] else {
                throw AppError.validationError(
                    ValidationError(
                        field: "goalId",
                        message: "Allocation references unknown goal \(allocation.goalId).",
                        code: .splitNotHundred
                    )
                )
            }
            let nextSaved = goal.savedAmount - allocation.amount
            guard nextSaved >= 0 else {
                throw AppError.validationError(
                    ValidationError(
                        field: "reductions",
                        message: goalBelowZeroMessage(goal: goal),
                        code: .goalBelowZero
                    )
                )
            }
            goal.savedAmount = nextSaved
            goal.updatedAt = now
            goalsByID[allocation.goalId] = goal
        }

        next.goals = next.goals.map { goalsByID[$0.id] ?? $0 }
        next.accounts = next.accounts.map { account in
            guard account.isDedicated else { return account }
            var updated = account
            updated.balance = newBalance
            return updated
        }
        next.history.append(entry)
        // Standing split intentionally unchanged.
        return next
    }

    /// Clamps a single reduction to 0…savedAmount for that goal (blocks below-zero edits).
    static func clampedReduction(amount: Paisa, for goal: Goal) -> Paisa {
        min(max(amount, 0), goal.savedAmount)
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
