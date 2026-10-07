import Foundation

/// Outcome of comparing previous vs fetched/typed balance (frames 10 / 10a / 10b).
enum BalanceCompareResult: Equatable, Sendable {
    /// Fetched/typed > previous → open New credit History entry.
    case higher(creditAmount: Paisa, previousBalance: Paisa, newBalance: Paisa)
    /// Equal → no-op message, no History write (PRD R26).
    case same
    /// Lower → trigger Withdrawal flow (stub callback; full UI out of scope).
    case lower(shortfall: Paisa, previousBalance: Paisa, newBalance: Paisa)
}

/// Pure Sync / Update / Credit-entry state machine (PRD R7–R9, R26; Spec BR-5, BR-6).
/// Linux-testable without SwiftUI. Reuses `OpeningSplitService` for 100% validation.
enum CreditEntryService {
    /// Copy for same-balance sync (frame 10a / PRD R26).
    static let noNewCreditMessage = "No new credit since the last sync."

    /// Banner title fragment (frame 9b / PRD R9).
    static let openEntryBannerPrefix = "New credit found"

    /// CTA on open-entry banner.
    static let assignNowTitle = "Assign now"

    /// Caption after lock (frames 13a / 13d).
    static let lockedOnceCaption = "You can change this split once."

    /// Optional standing-split checkbox copy (frame 13b).
    static let useThisSplitCheckboxTitle = "Use this split from the next credit too"

    // MARK: - Balance compare (R7 / R26 / 10b)

    static func compare(previousBalance: Paisa, newBalance: Paisa) -> BalanceCompareResult {
        if newBalance > previousBalance {
            return .higher(
                creditAmount: newBalance - previousBalance,
                previousBalance: previousBalance,
                newBalance: newBalance
            )
        }
        if newBalance == previousBalance {
            return .same
        }
        return .lower(
            shortfall: previousBalance - newBalance,
            previousBalance: previousBalance,
            newBalance: newBalance
        )
    }

    // MARK: - Open entry discovery (BR-6 / R9)

    /// Unsaved New credit entry, if any (newest first preference).
    static func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry? {
        history
            .filter { $0.type == .newCredit && !$0.isLocked }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    /// BR-6: Sync / Update blocked while an open credit entry exists.
    static func isSyncOrUpdateBlocked(history: [HistoryEntry]) -> Bool {
        openCreditEntry(in: history) != nil
    }

    /// Banner copy for Goals (9b): "New credit found … Assign now".
    static func openEntryBannerMessage(creditAmount: Paisa, formatting: any FormattingServicing) -> String {
        let amount = formatting.formatINR(paisa: creditAmount)
        return "\(openEntryBannerPrefix) \(amount). \(assignNowTitle)"
    }

    static func openEntryBannerMessage(for entry: HistoryEntry, formatting: any FormattingServicing) -> String {
        let amount = entry.creditAmount ?? 0
        return openEntryBannerMessage(creditAmount: amount, formatting: formatting)
    }

    // MARK: - Default / suggested standing percentages (standing → this credit)

    /// Suggested this-credit split from standing splits / goal shares (PIP-103).
    /// Single goal → 100% (frame 13e). Alias of `defaultPercentages`.
    static func suggestedStandingPercentages(
        goals: [Goal],
        standingSplits: [StandingSplit]
    ) -> [UUID: Decimal] {
        defaultPercentages(goals: goals, standingSplits: standingSplits)
    }

    /// Defaults for this-credit-only split from standing splits / goal shares.
    /// Single goal → 100% (frame 13e).
    static func defaultPercentages(goals: [Goal], standingSplits: [StandingSplit]) -> [UUID: Decimal] {
        if goals.count == 1, let goal = goals.first {
            return OpeningSplitService.singleGoalPercentages(goalID: goal.id)
        }

        let standingMap = Dictionary(uniqueKeysWithValues: standingSplits.map {
            ($0.goalId, $0.percentage)
        })
        var fractions: [UUID: Decimal] = [:]
        for goal in goals {
            if let standing = standingMap[goal.id] {
                fractions[goal.id] = standing
            } else {
                fractions[goal.id] = goal.shareOfNewCredits
            }
        }
        let ordered = goals.map { fractions[$0.id] ?? 0 }
        if OpeningSplitService.isValidHundredPercent(ordered) {
            return fractions
        }
        return equalPercentages(for: goals)
    }

    /// Whether this-credit percentages differ from the suggested standing split (PIP-103).
    static func isCustomSplit(
        percentages: [UUID: Decimal],
        suggested: [UUID: Decimal]
    ) -> Bool {
        let keys = Set(percentages.keys).union(suggested.keys)
        for key in keys {
            let left = (percentages[key] ?? 0).rounded(scale: 4)
            let right = (suggested[key] ?? 0).rounded(scale: 4)
            if left != right {
                return true
            }
        }
        return false
    }

    static func equalPercentages(for goals: [Goal]) -> [UUID: Decimal] {
        guard !goals.isEmpty else { return [:] }
        let count = Decimal(goals.count)
        let base = (Decimal(1) / count).rounded(scale: 4)
        var result: [UUID: Decimal] = [:]
        var assigned = Decimal(0)
        for (index, goal) in goals.enumerated() {
            if index == goals.count - 1 {
                result[goal.id] = (Decimal(1) - assigned).rounded(scale: 4)
            } else {
                result[goal.id] = base
                assigned += base
            }
        }
        return result
    }

    // MARK: - Create open entry (R7)

    /// Creates an unlocked New credit History entry. Does not mutate goal saved amounts yet.
    static func createOpenCreditEntry(
        goals: [Goal],
        standingSplits: [StandingSplit],
        previousBalance: Paisa,
        newBalance: Paisa,
        creditAmount: Paisa,
        isTyped: Bool,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> HistoryEntry {
        guard creditAmount > 0, newBalance == previousBalance + creditAmount else {
            throw AppError.validationError(
                ValidationError(
                    field: "creditAmount",
                    message: "Credit amount must equal the increase in balance.",
                    code: .splitNotHundred
                )
            )
        }
        guard !goals.isEmpty else {
            throw AppError.validationError(
                ValidationError(
                    field: "goals",
                    message: "At least one goal is required to assign a credit.",
                    code: .splitNotHundred
                )
            )
        }

        let percentages = defaultPercentages(goals: goals, standingSplits: standingSplits)
        let allocations = try OpeningSplitService.makeAllocations(
            goals: goals,
            openingBalance: creditAmount,
            percentages: percentages
        )

        return HistoryEntry(
            id: id,
            type: .newCredit,
            createdAt: createdAt,
            isLocked: false,
            previousBalance: previousBalance,
            newBalance: newBalance,
            creditAmount: creditAmount,
            isTyped: isTyped,
            customSplit: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: allocations
        )
    }

    // MARK: - Create goal while open (PIP-103 / R10)

    /// Inserts a goal (saved ₹0) into an open New credit without changing existing goal totals.
    /// Rebuilds this-credit allocations: new goal at 0%, prior rows keep their percentages.
    static func addGoalToOpenCredit(
        to state: PersistedAppState,
        entryID: UUID,
        goal: Goal,
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard let index = state.history.firstIndex(where: { $0.id == entryID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "entryID",
                    message: "Credit entry not found.",
                    code: .splitNotHundred
                )
            )
        }

        var entry = state.history[index]
        guard entry.type == .newCredit, !entry.isLocked else {
            throw AppError.validationError(
                ValidationError(
                    field: "isLocked",
                    message: "Goals can only be added on an open New credit entry.",
                    code: .splitNotHundred
                )
            )
        }

        var next = state
        var inserted = goal
        inserted.savedAmount = 0
        inserted.updatedAt = now
        if !next.goals.contains(where: { $0.id == inserted.id }) {
            next.goals.append(inserted)
        }

        // Standing: keep prior weights; new goal starts at 0% until Save / standing edit.
        if !next.standingSplits.contains(where: { $0.goalId == inserted.id }) {
            next.standingSplits.append(StandingSplit(goalId: inserted.id, percentage: 0))
        }

        let creditAmount = entry.creditAmount ?? 0
        var percentages = Dictionary(uniqueKeysWithValues: entry.allocations.map {
            ($0.goalId, $0.percentage)
        })
        percentages[inserted.id] = percentages[inserted.id] ?? 0

        let allocations = try OpeningSplitService.makeAllocations(
            goals: next.goals,
            openingBalance: creditAmount,
            percentages: percentages
        )
        entry.allocations = allocations
        // Adding a goal while open starts a custom this-credit path until Save resolves the flag.
        entry.customSplit = true
        next.history[index] = entry
        return next
    }

    /// Applies an open credit: updates dedicated balance, appends unlocked History entry.
    /// Rejects when another open credit already exists (BR-6).
    static func applyOpenCredit(
        to state: PersistedAppState,
        entry: HistoryEntry,
        dedicatedAccountID: UUID
    ) throws -> PersistedAppState {
        guard entry.type == .newCredit else {
            throw AppError.validationError(
                ValidationError(
                    field: "type",
                    message: "Expected a New credit History entry.",
                    code: .splitNotHundred
                )
            )
        }
        guard !entry.isLocked else {
            throw AppError.validationError(
                ValidationError(
                    field: "isLocked",
                    message: "Open credit entry must start unlocked.",
                    code: .splitNotHundred
                )
            )
        }
        if isSyncOrUpdateBlocked(history: state.history) {
            throw AppError.validationError(
                ValidationError(
                    field: "history",
                    message: "An open credit must be assigned before Sync or Update.",
                    code: .splitNotHundred
                )
            )
        }

        var next = state
        guard let newBalance = entry.newBalance else {
            throw AppError.validationError(
                ValidationError(
                    field: "newBalance",
                    message: "Credit entry requires a new balance.",
                    code: .splitNotHundred
                )
            )
        }

        var foundDedicated = false
        next.accounts = next.accounts.map { account in
            guard account.id == dedicatedAccountID else { return account }
            foundDedicated = true
            var updated = account
            updated.balance = newBalance
            return updated
        }
        guard foundDedicated else {
            throw AppError.validationError(
                ValidationError(
                    field: "accounts",
                    message: "Dedicated savings account not found.",
                    code: .noDedicatedAccount
                )
            )
        }

        next.history.append(entry)
        return next
    }

    // MARK: - Lock once (BR-5 / R8)

    /// Rebuilds allocations for Save and lock from edited percentages.
    static func allocationsForSave(
        goals: [Goal],
        creditAmount: Paisa,
        percentages: [UUID: Decimal]
    ) throws -> [GoalAllocation] {
        try OpeningSplitService.makeAllocations(
            goals: goals,
            openingBalance: creditAmount,
            percentages: percentages
        )
    }

    /// Whether Save and lock is enabled (100% + still open).
    static func canSaveAndLock(entry: HistoryEntry, fractions: [Decimal]) -> Bool {
        !entry.isLocked
            && entry.type == .newCredit
            && OpeningSplitService.isValidHundredPercent(fractions)
    }

    /// Locks the open credit: updates goal saved amounts; optionally standing split.
    /// BR-5: after this, entry is immutable (no second % edit).
    static func applyCreditLock(
        to state: PersistedAppState,
        entryID: UUID,
        percentages: [UUID: Decimal],
        useThisSplitForStanding: Bool,
        now: Date = Date()
    ) throws -> PersistedAppState {
        guard let index = state.history.firstIndex(where: { $0.id == entryID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "entryID",
                    message: "Credit entry not found.",
                    code: .splitNotHundred
                )
            )
        }

        var entry = state.history[index]
        guard entry.type == .newCredit else {
            throw AppError.validationError(
                ValidationError(
                    field: "type",
                    message: "Only New credit entries can be locked here.",
                    code: .splitNotHundred
                )
            )
        }
        guard !entry.isLocked else {
            throw AppError.validationError(
                ValidationError(
                    field: "isLocked",
                    message: "This credit is already locked.",
                    code: .splitNotHundred
                )
            )
        }

        let creditAmount = entry.creditAmount ?? 0
        guard creditAmount > 0 else {
            throw AppError.validationError(
                ValidationError(
                    field: "creditAmount",
                    message: "Credit amount must be positive.",
                    code: .splitNotHundred
                )
            )
        }

        let allocations = try allocationsForSave(
            goals: state.goals,
            creditAmount: creditAmount,
            percentages: percentages
        )

        let suggested = suggestedStandingPercentages(
            goals: state.goals,
            standingSplits: state.standingSplits
        )
        entry.allocations = allocations
        entry.isLocked = true
        entry.customSplit = isCustomSplit(percentages: percentages, suggested: suggested)

        var next = state
        var goalsByID = Dictionary(uniqueKeysWithValues: next.goals.map { ($0.id, $0) })

        for allocation in allocations {
            guard var goal = goalsByID[allocation.goalId] else {
                throw AppError.validationError(
                    ValidationError(
                        field: "goalId",
                        message: "Allocation references unknown goal \(allocation.goalId).",
                        code: .splitNotHundred
                    )
                )
            }
            // Goal totals update on Save only (PIP-103).
            goal.savedAmount += allocation.amount
            if useThisSplitForStanding {
                goal.shareOfNewCredits = allocation.percentage
            }
            goal.updatedAt = now
            goalsByID[allocation.goalId] = goal
        }

        next.goals = next.goals.map { goalsByID[$0.id] ?? $0 }
        next.history[index] = entry

        if useThisSplitForStanding {
            next.standingSplits = allocations.map {
                StandingSplit(goalId: $0.goalId, percentage: $0.percentage)
            }
        }

        return next
    }

    // MARK: - Sync / Update orchestration helpers

    /// Full Sync path after a successful fetch (frames 10 / 10a / 10b).
    static func processFetchedBalance(
        state: PersistedAppState,
        fetchedBalance: Paisa,
        dedicatedAccountID: UUID,
        isTyped: Bool,
        id: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> CreditProcessOutcome {
        if isSyncOrUpdateBlocked(history: state.history) {
            throw AppError.validationError(
                ValidationError(
                    field: "history",
                    message: "An open credit must be assigned before Sync or Update.",
                    code: .splitNotHundred
                )
            )
        }

        guard let dedicated = state.accounts.first(where: {
            $0.id == dedicatedAccountID || $0.isDedicated
        }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "accounts",
                    message: "Dedicated savings account not found.",
                    code: .noDedicatedAccount
                )
            )
        }

        let previous = dedicated.balance
        switch compare(previousBalance: previous, newBalance: fetchedBalance) {
        case .same:
            return .noNewCredit(message: noNewCreditMessage)

        case .lower(let shortfall, let previousBalance, let newBalance):
            return .withdrawalRequired(
                shortfall: shortfall,
                previousBalance: previousBalance,
                newBalance: newBalance
            )

        case .higher(let creditAmount, let previousBalance, let newBalance):
            let entry = try createOpenCreditEntry(
                goals: state.goals,
                standingSplits: state.standingSplits,
                previousBalance: previousBalance,
                newBalance: newBalance,
                creditAmount: creditAmount,
                isTyped: isTyped,
                id: id,
                createdAt: createdAt
            )
            let next = try applyOpenCredit(
                to: state,
                entry: entry,
                dedicatedAccountID: dedicatedAccountID
            )
            return .openCreditCreated(state: next, entry: entry)
        }
    }
}

/// Result of Sync / typed Update processing.
enum CreditProcessOutcome: Equatable, Sendable {
    case noNewCredit(message: String)
    case withdrawalRequired(shortfall: Paisa, previousBalance: Paisa, newBalance: Paisa)
    case openCreditCreated(state: PersistedAppState, entry: HistoryEntry)
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
