import Foundation

/// Transfer between goals (PRD R14, Spec BR-7 / frames 16 / 16a–16c).
/// Pure / Linux-testable. Amounts in paisa (`Int64`); standing split is never mutated.
enum TransferService {
    /// UI / flow phases for frames 16 / 16a–16c.
    enum Phase: String, Equatable, Sendable {
        case select
        case enterAmount
        case preview
        case overAmount
        case complete
    }

    /// Quick-amount chips (rupees) — design frame 16.
    static let chipRupees: [Paisa] = [1_000, 5_000, 10_000]

    /// History type label (PRD: From → To · amount).
    static let historyTypeLabel = "Transfer"

    /// Caption under the Transfer form.
    static let caption =
        "Move saved money between goals. Standing split stays the same."

    /// Over-amount helper (frame 16b).
    static let overAmountMessage =
        "Amount is more than the From goal’s saved balance. Move stays disabled."

    // MARK: - Prefill (Ask 16c)

    /// Optional prefill from Ask proposal / deep link.
    struct Prefill: Equatable, Sendable {
        var fromGoalId: UUID?
        var toGoalId: UUID?
        var amountPaisa: Paisa?
    }

    // MARK: - Chips / parsing

    /// Converts whole rupees to paisa.
    static func paisa(fromRupees rupees: Paisa) -> Paisa {
        rupees * 100
    }

    /// Chip amount in paisa for index into `chipRupees`.
    static func chipAmountPaisa(at index: Int) -> Paisa? {
        guard chipRupees.indices.contains(index) else { return nil }
        return paisa(fromRupees: chipRupees[index])
    }

    /// Parses a rupee amount string (digits / grouping) into paisa. Empty → 0.
    static func parseAmountPaisa(fromRupeesText text: String) -> Paisa {
        let digits = text.filter(\.isNumber)
        guard let rupees = Paisa(digits) else { return 0 }
        return paisa(fromRupees: rupees)
    }

    // MARK: - Selection helpers

    static func goal(id: UUID?, in goals: [Goal]) -> Goal? {
        guard let id else { return nil }
        return goals.first { $0.id == id }
    }

    /// Goals available for the To selector (excludes From).
    static func toCandidates(fromGoalId: UUID?, goals: [Goal]) -> [Goal] {
        goals.filter { $0.id != fromGoalId }
    }

    // MARK: - Validation / phase

    /// True when amount is positive and ≤ From saved.
    static func isAmountValid(amountPaisa: Paisa, fromSaved: Paisa) -> Bool {
        amountPaisa > 0 && amountPaisa <= fromSaved
    }

    /// True when amount exceeds From saved (frame 16b). Zero is not over-amount.
    static func isOverAmount(amountPaisa: Paisa, fromSaved: Paisa) -> Bool {
        amountPaisa > 0 && amountPaisa > fromSaved
    }

    /// Derives UI phase from current selections and amount.
    static func resolvePhase(
        fromGoalId: UUID?,
        toGoalId: UUID?,
        amountPaisa: Paisa,
        goals: [Goal],
        isComplete: Bool
    ) -> Phase {
        if isComplete { return .complete }

        let from = goal(id: fromGoalId, in: goals)
        let to = goal(id: toGoalId, in: goals)
        guard from != nil, to != nil, from?.id != to?.id else {
            return .select
        }

        let saved = from?.savedAmount ?? 0
        if isOverAmount(amountPaisa: amountPaisa, fromSaved: saved) {
            return .overAmount
        }
        if amountPaisa <= 0 {
            return .enterAmount
        }
        if isAmountValid(amountPaisa: amountPaisa, fromSaved: saved) {
            return .preview
        }
        return .enterAmount
    }

    /// Move enabled only for valid preview state.
    /// Complete is terminal: `isComplete == true` always disables Move (no double-transfer).
    static func canMove(
        fromGoalId: UUID?,
        toGoalId: UUID?,
        amountPaisa: Paisa,
        goals: [Goal],
        isMoving: Bool = false,
        isComplete: Bool = false
    ) -> Bool {
        guard !isComplete else { return false }
        guard !isMoving else { return false }
        guard let from = goal(id: fromGoalId, in: goals),
              let to = goal(id: toGoalId, in: goals),
              from.id != to.id
        else {
            return false
        }
        return isAmountValid(amountPaisa: amountPaisa, fromSaved: from.savedAmount)
    }

    // MARK: - Preview

    struct BalancePreview: Equatable, Sendable {
        var fromGoalId: UUID
        var toGoalId: UUID
        var fromName: String
        var toName: String
        var fromBefore: Paisa
        var fromAfter: Paisa
        var toBefore: Paisa
        var toAfter: Paisa
        var amountPaisa: Paisa
    }

    /// After-transfer balances when amount is valid; nil otherwise.
    static func preview(
        fromGoalId: UUID?,
        toGoalId: UUID?,
        amountPaisa: Paisa,
        goals: [Goal]
    ) -> BalancePreview? {
        guard let from = goal(id: fromGoalId, in: goals),
              let to = goal(id: toGoalId, in: goals),
              from.id != to.id,
              isAmountValid(amountPaisa: amountPaisa, fromSaved: from.savedAmount)
        else {
            return nil
        }
        return BalancePreview(
            fromGoalId: from.id,
            toGoalId: to.id,
            fromName: from.name,
            toName: to.name,
            fromBefore: from.savedAmount,
            fromAfter: from.savedAmount - amountPaisa,
            toBefore: to.savedAmount,
            toAfter: to.savedAmount + amountPaisa,
            amountPaisa: amountPaisa
        )
    }

    // MARK: - History

    /// Presentation title: "Car → Emergency Fund · ₹5,000".
    static func historyTitle(
        fromName: String,
        toName: String,
        amountPaisa: Paisa,
        formatting: any FormattingServicing = FormattingService()
    ) -> String {
        "\(fromName) → \(toName) · \(formatting.formatINR(paisa: amountPaisa))"
    }

    /// Locked Transfer History entry (frame 16a).
    static func createLockedTransferEntry(
        from: Goal,
        to: Goal,
        amountPaisa: Paisa,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        guard from.id != to.id else {
            throw AppError.validationError(
                ValidationError(
                    field: "toGoalId",
                    message: "Choose two different goals.",
                    code: .emptyName
                )
            )
        }
        guard isAmountValid(amountPaisa: amountPaisa, fromSaved: from.savedAmount) else {
            throw AppError.validationError(
                ValidationError(
                    field: "amount",
                    message: overAmountMessage,
                    code: .amountExceedsSaved
                )
            )
        }

        let allocations = [
            GoalAllocation(
                goalId: from.id,
                goalName: from.name,
                amount: amountPaisa,
                percentage: 1
            ),
            GoalAllocation(
                goalId: to.id,
                goalName: to.name,
                amount: amountPaisa,
                percentage: 1
            )
        ]

        return HistoryEntry(
            id: id,
            type: .transfer,
            createdAt: createdAt,
            isLocked: true,
            previousBalance: nil,
            newBalance: nil,
            creditAmount: nil,
            isTyped: nil,
            fromGoalId: from.id,
            toGoalId: to.id,
            transferAmount: amountPaisa,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: allocations
        )
    }

    // MARK: - Apply

    /// Moves money From → To, appends locked History, leaves standing split unchanged (BR-7).
    static func applyTransfer(
        to state: PersistedAppState,
        fromGoalId: UUID,
        toGoalId: UUID,
        amountPaisa: Paisa,
        entryID: UUID = UUID(),
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard let from = state.goals.first(where: { $0.id == fromGoalId }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "fromGoalId",
                    message: "From goal not found.",
                    code: .emptyName
                )
            )
        }
        guard let to = state.goals.first(where: { $0.id == toGoalId }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "toGoalId",
                    message: "To goal not found.",
                    code: .emptyName
                )
            )
        }

        let entry = try createLockedTransferEntry(
            from: from,
            to: to,
            amountPaisa: amountPaisa,
            id: entryID,
            createdAt: now
        )

        // Snapshot standing split before mutation — must remain byte-equal after.
        let standingBefore = state.standingSplits
        let sharesBefore = Dictionary(uniqueKeysWithValues: state.goals.map {
            ($0.id, $0.shareOfNewCredits)
        })

        var next = state
        var goals = next.goals
        guard let fromIndex = goals.firstIndex(where: { $0.id == fromGoalId }),
              let toIndex = goals.firstIndex(where: { $0.id == toGoalId })
        else {
            throw AppError.validationError(
                ValidationError(
                    field: "goalId",
                    message: "Goal not found.",
                    code: .emptyName
                )
            )
        }

        goals[fromIndex].savedAmount -= amountPaisa
        goals[fromIndex].updatedAt = now
        goals[toIndex].savedAmount += amountPaisa
        goals[toIndex].updatedAt = now

        // Restore shares explicitly so BR-7 holds even if callers mutate elsewhere.
        for index in goals.indices {
            if let share = sharesBefore[goals[index].id] {
                goals[index].shareOfNewCredits = share
            }
        }

        next.goals = goals
        next.standingSplits = standingBefore
        next.history.append(entry)
        return next
    }
}
