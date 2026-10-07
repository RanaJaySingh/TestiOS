import Combine
import Foundation

/// View model for Opening split (frames 8 / 8b) — PRD R6, R22; Spec BR-2, BR-3.
@MainActor
final class OpeningSplitViewModel: ObservableObject {
    /// Whole-number display percents keyed by goal id (0…100). Empty / unused in single-goal mode.
    @Published private(set) var displayPercents: [UUID: Int]
    @Published private(set) var isLocking = false
    @Published var showConfirmLock = false
    @Published private(set) var errorMessage: String?
    /// Set after a successful lock so the view can navigate to Goals (9).
    @Published private(set) var shouldNavigateToGoals = false
    /// When non-nil, screen is viewing a locked opening entry (read-only).
    @Published private(set) var lockedEntry: HistoryEntry?
    /// One-goal skip path: Opening split UI skipped; 100% locked automatically.
    @Published private(set) var didAutoSkip = false

    let goals: [Goal]
    let openingBalance: Paisa
    /// Propagated into Opening balance History (`isTyped`) — Manual vs PIN/Yes fetch (PIP-100).
    let openingBalanceIsTyped: Bool
    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID

    var isSingleGoal: Bool { goals.count == 1 }
    /// Multi-goal editor only; single-goal skips Opening split screens (PIP-101).
    var shouldPresentEditor: Bool { OpeningSplitService.shouldPresentEditor(goalCount: goals.count) }
    var isReadOnly: Bool { lockedEntry != nil }

    var formattedOpeningBalance: String {
        formatting.formatINR(paisa: openingBalance)
    }

    var fractionMap: [UUID: Decimal] {
        if isSingleGoal, let goal = goals.first {
            return OpeningSplitService.singleGoalPercentages(goalID: goal.id)
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
        OpeningSplitService.totalDisplayPercent(orderedFractions)
    }

    var canLock: Bool {
        !isReadOnly
            && !isLocking
            && shouldPresentEditor
            && OpeningSplitService.isValidHundredPercent(orderedFractions)
    }

    var statusMessage: String {
        if isReadOnly {
            return OpeningSplitService.lockedAmountsCaption
        }
        if isSingleGoal {
            return "One goal — opening split is 100% automatic."
        }
        return OpeningSplitService.shortfallMessage(for: orderedFractions)
            ?? "Total 100%. Ready to lock."
    }

    init(
        goals: [Goal],
        openingBalance: Paisa,
        openingBalanceIsTyped: Bool = true,
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        initialPercents: [UUID: Int]? = nil,
        lockedEntry: HistoryEntry? = nil,
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.goals = goals
        self.openingBalance = openingBalance
        self.openingBalanceIsTyped = openingBalanceIsTyped
        self.persistence = persistence
        self.formatting = formatting
        self.clock = clock
        self.makeID = makeID
        self.lockedEntry = lockedEntry

        if goals.count == 1, let goal = goals.first {
            self.displayPercents = [goal.id: 100]
        } else if let initialPercents {
            self.displayPercents = Dictionary(uniqueKeysWithValues: goals.map { goal in
                (goal.id, initialPercents[goal.id] ?? 0)
            })
        } else {
            // Prefer standing / shareOfNewCredits when present; otherwise equal split.
            let fromShares = goals.map { goal -> (UUID, Int) in
                let display = (goal.shareOfNewCredits * 100).roundedTowardZeroInt
                return (goal.id, display)
            }
            let shareTotal = fromShares.reduce(0) { $0 + $1.1 }
            if shareTotal == 100 {
                self.displayPercents = Dictionary(uniqueKeysWithValues: fromShares)
            } else {
                self.displayPercents = Self.equalDisplayPercents(for: goals)
            }
        }
    }

    /// Factory for viewing a locked opening entry later (History) — always read-only.
    static func readOnly(
        entry: HistoryEntry,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService()
    ) -> OpeningSplitViewModel {
        let balance = entry.creditAmount ?? entry.newBalance ?? 0
        let percents = Dictionary(uniqueKeysWithValues: entry.allocations.map {
            ($0.goalId, ($0.percentage * 100).roundedTowardZeroInt)
        })
        return OpeningSplitViewModel(
            goals: goals.isEmpty
                ? entry.allocations.map { allocation in
                    Goal(
                        id: allocation.goalId,
                        name: allocation.goalName,
                        targetAmount: 0,
                        startDate: entry.createdAt,
                        endDate: entry.createdAt,
                        inflationRate: Decimal(string: "0.07")!,
                        savedAmount: allocation.amount,
                        shareOfNewCredits: allocation.percentage,
                        createdAt: entry.createdAt,
                        updatedAt: entry.createdAt
                    )
                }
                : goals,
            openingBalance: balance,
            openingBalanceIsTyped: entry.isTyped ?? true,
            persistence: persistence,
            formatting: formatting,
            initialPercents: percents,
            lockedEntry: entry
        )
    }

    func setDisplayPercent(goalID: UUID, percent: Int) {
        guard !isReadOnly, !isSingleGoal else { return }
        let clamped = min(max(percent, 0), 100)
        displayPercents[goalID] = clamped
        errorMessage = nil
    }

    func amount(for goalID: UUID) -> Paisa {
        if let locked = lockedEntry,
           let allocation = locked.allocations.first(where: { $0.goalId == goalID }) {
            return allocation.amount
        }
        let fractions = orderedFractions
        let amounts = OpeningSplitService.allocatePaisa(total: openingBalance, fractions: fractions)
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return 0 }
        return amounts[index]
    }

    func formattedAmount(for goalID: UUID) -> String {
        formatting.formatINR(paisa: amount(for: goalID))
    }

    func requestLock() {
        guard canLock else { return }
        showConfirmLock = true
    }

    /// One-goal skip: lock Opening at 100% + standing split, then navigate to Goals (PIP-101).
    /// History `isTyped` from tip PIP-100; write path via `StubLedgerService` + `LedgerFacade` ancestry.
    func applySingleGoalSkipIfNeeded() async {
        guard isSingleGoal, !didAutoSkip, !isReadOnly else { return }
        isLocking = true
        errorMessage = nil
        defer { isLocking = false }

        do {
            let state = try await persistence.loadState()
            let (next, entry) = try StubLedgerService.lockSingleGoalOpening(
                to: state,
                goals: goals,
                openingBalance: openingBalance,
                isTyped: openingBalanceIsTyped,
                entryID: makeID(),
                createdAt: clock(),
                now: clock()
            )
            try await persistence.saveState(next)
            lockedEntry = entry
            didAutoSkip = true
            shouldNavigateToGoals = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Confirms lock: tip History shape (`isTyped`) + standing splits, then Goals (9).
    func confirmLock() async {
        guard canLock else { return }
        isLocking = true
        errorMessage = nil
        defer { isLocking = false }

        do {
            let state = try await persistence.loadState()
            let (next, entry) = try StubLedgerService.lockOpeningBalance(
                to: state,
                goals: goals,
                openingBalance: openingBalance,
                percentages: fractionMap,
                isTyped: openingBalanceIsTyped,
                entryID: makeID(),
                createdAt: clock(),
                now: clock()
            )
            try await persistence.saveState(next)
            lockedEntry = entry
            shouldNavigateToGoals = true
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func equalDisplayPercents(for goals: [Goal]) -> [UUID: Int] {
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
    var roundedTowardZeroInt: Int {
        NSDecimalNumber(decimal: self).intValue
    }
}
