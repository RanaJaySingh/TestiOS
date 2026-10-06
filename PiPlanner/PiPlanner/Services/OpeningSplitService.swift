import Foundation

/// Opening split validation and History lock helpers (PRD R6 / R22, Spec BR-2 / BR-3).
enum OpeningSplitService {
    /// Exact hundredths of a percent as basis points of 100% (10_000 = 100.00%).
    /// Display percentages are whole percents 0…100; fractions are 0.0…1.0.
    static let hundredPercentFraction = Decimal(1)
    static let hundredPercentDisplay = Decimal(100)

    // MARK: - Validation (BR-2 / R22)

    /// Returns true when fractions (0.0–1.0) sum to exactly 100%.
    static func isValidHundredPercent(_ fractions: [Decimal]) -> Bool {
        guard !fractions.isEmpty else { return false }
        return normalizedTotal(fractions) == hundredPercentFraction
    }

    /// Sum of fractions (0.0–1.0), normalized to avoid float noise from Double bridging.
    static func normalizedTotal(_ fractions: [Decimal]) -> Decimal {
        let sum = fractions.reduce(Decimal(0), +)
        return sum.rounded(scale: 4)
    }

    /// Running total as a display percent 0…100+.
    static func totalDisplayPercent(_ fractions: [Decimal]) -> Decimal {
        (normalizedTotal(fractions) * hundredPercentDisplay).rounded(scale: 2)
    }

    /// Shortfall copy when total ≠ 100% (PRD R22 example style).
    static func shortfallMessage(for fractions: [Decimal]) -> String? {
        let total = totalDisplayPercent(fractions)
        if total == hundredPercentDisplay {
            return nil
        }
        if total < hundredPercentDisplay {
            let remaining = (hundredPercentDisplay - total).rounded(scale: 2)
            return "Total \(formatPercent(total)). Assign the remaining \(formatPercent(remaining))."
        }
        let over = (total - hundredPercentDisplay).rounded(scale: 2)
        return "Total \(formatPercent(total)). Reduce by \(formatPercent(over))."
    }

    // MARK: - Allocations

    /// Builds per-goal allocations that sum exactly to `openingBalance` (paisa).
    static func makeAllocations(
        goals: [Goal],
        openingBalance: Paisa,
        percentages: [UUID: Decimal]
    ) throws -> [GoalAllocation] {
        guard !goals.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "At least one goal is required for opening split.",
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

        let amounts = allocatePaisa(total: openingBalance, fractions: orderedFractions)
        return zip(goals, zip(orderedFractions, amounts)).map { goal, pair in
            let (fraction, amount) = pair
            return GoalAllocation(
                goalId: goal.id,
                goalName: goal.name,
                amount: amount,
                percentage: fraction.rounded(scale: 4)
            )
        }
    }

    /// Largest-remainder allocation so paisa amounts sum exactly to `total`.
    static func allocatePaisa(total: Paisa, fractions: [Decimal]) -> [Paisa] {
        guard !fractions.isEmpty else { return [] }
        guard total >= 0 else { return Array(repeating: 0, count: fractions.count) }

        struct Remainder: Comparable {
            let index: Int
            let fraction: Double
            static func < (lhs: Remainder, rhs: Remainder) -> Bool {
                if lhs.fraction == rhs.fraction {
                    return lhs.index < rhs.index
                }
                return lhs.fraction < rhs.fraction
            }
        }

        var floors: [Paisa] = []
        var remainders: [Remainder] = []
        floors.reserveCapacity(fractions.count)

        for (index, fraction) in fractions.enumerated() {
            let exact = NSDecimalNumber(decimal: Decimal(total) * fraction).doubleValue
            let floorValue = Paisa(exact.rounded(.towardZero))
            floors.append(floorValue)
            remainders.append(Remainder(index: index, fraction: exact - Double(floorValue)))
        }

        let assigned = floors.reduce(Paisa(0), +)
        var leftover = total - assigned
        let ranked = remainders.sorted(by: >)
        var cursor = 0
        while leftover > 0 && cursor < ranked.count {
            floors[ranked[cursor].index] += 1
            leftover -= 1
            cursor += 1
        }
        return floors
    }

    // MARK: - History entry (BR-3 / R6)

    /// Creates a locked Opening balance History entry. Allocations never change after this.
    static func createLockedOpeningEntry(
        goals: [Goal],
        openingBalance: Paisa,
        percentages: [UUID: Decimal],
        id: UUID = UUID(),
        createdAt: Date = Date(),
        isTyped: Bool = true
    ) throws -> HistoryEntry {
        let allocations = try makeAllocations(
            goals: goals,
            openingBalance: openingBalance,
            percentages: percentages
        )
        return HistoryEntry(
            id: id,
            type: .openingBalance,
            createdAt: createdAt,
            isLocked: true,
            previousBalance: nil,
            newBalance: openingBalance,
            creditAmount: openingBalance,
            isTyped: isTyped,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: allocations
        )
    }

    /// Applies a locked opening entry: updates goal saved amounts + standing shares, appends history.
    static func applyOpeningLock(
        to state: PersistedAppState,
        entry: HistoryEntry,
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard entry.type == .openingBalance else {
            throw AppError.validationError(
                ValidationError(
                    field: "type",
                    message: "Expected an Opening balance History entry.",
                    code: .splitNotHundred
                )
            )
        }
        guard entry.isLocked else {
            throw AppError.validationError(
                ValidationError(
                    field: "isLocked",
                    message: "Opening balance entry must be locked when saved.",
                    code: .splitNotHundred
                )
            )
        }
        if state.history.contains(where: { $0.type == .openingBalance && $0.isLocked }) {
            throw AppError.validationError(
                ValidationError(
                    field: "history",
                    message: "Opening balance is already locked and cannot be changed.",
                    code: .splitNotHundred
                )
            )
        }

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
            goal.savedAmount = allocation.amount
            goal.shareOfNewCredits = allocation.percentage
            goal.updatedAt = now
            goalsByID[allocation.goalId] = goal
        }

        next.goals = next.goals.map { goalsByID[$0.id] ?? $0 }
        next.standingSplits = entry.allocations.map {
            StandingSplit(goalId: $0.goalId, percentage: $0.percentage)
        }
        next.history.append(entry)
        return next
    }

    /// Single-goal setup: auto-assign 100% with no editable % fields (frame 8b).
    static func singleGoalPercentages(goalID: UUID) -> [UUID: Decimal] {
        [goalID: hundredPercentFraction]
    }

    /// Read-only copy for locked opening entries (PRD R6 / R16 wording variant on ticket).
    static let lockedAmountsCaption = "Locked amounts never change"

    private static func formatPercent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        if number == number.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )) {
            return "\(number.intValue)%"
        }
        return "\(value)%"
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
