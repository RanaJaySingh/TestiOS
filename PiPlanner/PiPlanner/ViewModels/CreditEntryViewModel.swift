import Combine
import Foundation

/// View model for open / locked New credit History entry (frames 13 / 13a–13g / 13t).
/// PRD R7–R8; Spec BR-2, BR-5; PIP-103 open → save + create goal.
@MainActor
final class CreditEntryViewModel: ObservableObject {
    @Published private(set) var displayPercents: [UUID: Int]
    @Published var useThisSplitForStanding = false
    @Published private(set) var isSaving = false
    @Published private(set) var isCreatingGoal = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var entry: HistoryEntry
    @Published private(set) var goals: [Goal]
    @Published var showCreateGoalSheet = false
    @Published var createGoalName = ""
    @Published var createGoalTargetRupees = ""

    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let ledger: any LedgerEngine
    private let clock: () -> Date
    private let makeID: () -> UUID

    var isSingleGoal: Bool { goals.count == 1 }
    var isLocked: Bool { entry.isLocked }
    var isTyped: Bool { entry.isTyped == true }
    var showsCustomBadge: Bool { HistoryService.showsCustomSplitBadge(entry) }
    var showsTypedBadge: Bool { HistoryService.showsTypedBadge(entry) }

    var creditAmount: Paisa { entry.creditAmount ?? 0 }

    var formattedCreditAmount: String {
        formatting.formatINR(paisa: creditAmount)
    }

    var formattedPrevious: String? {
        guard let previous = entry.previousBalance else { return nil }
        return formatting.formatINR(paisa: previous)
    }

    var formattedNewBalance: String? {
        guard let newBalance = entry.newBalance else { return nil }
        return formatting.formatINR(paisa: newBalance)
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

    var canSave: Bool {
        CreditEntryService.canSaveAndLock(entry: entry, fractions: orderedFractions) && !isSaving
    }

    var statusMessage: String {
        if isLocked {
            return OpeningSplitService.lockedAmountsCaption
        }
        if isSingleGoal {
            return "100% assigned to \(goals.first?.name ?? "your goal")."
        }
        return OpeningSplitService.shortfallMessage(for: orderedFractions)
            ?? "Total 100%. Ready to save and lock."
    }

    init(
        entry: HistoryEntry,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        ledger: any LedgerEngine = StubLedgerEngine(),
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.entry = entry
        self.goals = goals
        self.persistence = persistence
        self.formatting = formatting
        self.ledger = ledger
        self.clock = clock
        self.makeID = makeID
        self.displayPercents = Self.percents(from: entry, goals: goals)
    }

    private static func percents(from entry: HistoryEntry, goals: [Goal]) -> [UUID: Int] {
        if goals.count == 1, let goal = goals.first {
            return [goal.id: 100]
        }
        var map = Dictionary(uniqueKeysWithValues: entry.allocations.map {
            ($0.goalId, ($0.percentage * 100).roundedTowardZeroInt)
        })
        for goal in goals where map[goal.id] == nil {
            map[goal.id] = 0
        }
        return map
    }

    func openCreateGoal() {
        guard !isLocked else { return }
        createGoalName = ""
        createGoalTargetRupees = ""
        errorMessage = nil
        showCreateGoalSheet = true
    }

    static func load(
        entryID: UUID,
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService()
    ) async throws -> CreditEntryViewModel {
        let state = try await persistence.loadState()
        guard let entry = state.history.first(where: { $0.id == entryID }) else {
            throw AppError.validationError(
                ValidationError(
                    field: "entryID",
                    message: "Credit entry not found.",
                    code: .splitNotHundred
                )
            )
        }
        return CreditEntryViewModel(
            entry: entry,
            goals: state.goals,
            persistence: persistence,
            formatting: formatting
        )
    }

    func setDisplayPercent(goalID: UUID, percent: Int) {
        guard !isLocked, !isSingleGoal else { return }
        displayPercents[goalID] = min(max(percent, 0), 100)
        errorMessage = nil
    }

    func amount(for goalID: UUID) -> Paisa {
        if isLocked,
           let allocation = entry.allocations.first(where: { $0.goalId == goalID }) {
            return allocation.amount
        }
        let amounts = OpeningSplitService.allocatePaisa(
            total: creditAmount,
            fractions: orderedFractions
        )
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return 0 }
        return amounts[index]
    }

    func formattedAmount(for goalID: UUID) -> String {
        formatting.formatINR(paisa: amount(for: goalID))
    }

    /// Already-saved amount on the goal (unchanged until lock) — frame 13.
    func formattedSavedSoFar(for goal: Goal) -> String {
        formatting.formatINR(paisa: goal.savedAmount)
    }

    /// BR-5 / R8 / PIP-103: Save and lock once via StubLedgerEngine; optional standing split.
    func saveAndLock() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state = try await persistence.loadState()
            state = try ledger.saveAndLockCredit(
                state: state,
                entryID: entry.id,
                percentages: fractionMap,
                useThisSplitForStanding: useThisSplitForStanding,
                now: clock()
            )
            try await persistence.saveState(state)
            if let locked = state.history.first(where: { $0.id == entry.id }) {
                entry = locked
            }
            goals = state.goals
            displayPercents = Self.percents(from: entry, goals: goals)
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// PIP-103 / R10: Create goal while open — saved ₹0; goal totals unchanged until Save.
    func createGoal() async {
        guard !isLocked, !isCreatingGoal else { return }
        let trimmed = createGoalName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a goal name."
            return
        }
        let digits = createGoalTargetRupees.filter(\.isNumber)
        guard let rupees = Paisa(digits), rupees > 0 else {
            errorMessage = "Enter a target greater than ₹0."
            return
        }

        isCreatingGoal = true
        errorMessage = nil
        defer { isCreatingGoal = false }

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
            state = try ledger.addGoalToOpenCredit(
                state: state,
                entryID: entry.id,
                goal: goal,
                now: now
            )
            try await persistence.saveState(state)
            if let open = state.history.first(where: { $0.id == entry.id }) {
                entry = open
            }
            goals = state.goals
            displayPercents = Self.percents(from: entry, goals: goals)
            showCreateGoalSheet = false
            createGoalName = ""
            createGoalTargetRupees = ""
        } catch let error as AppError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Decimal {
    var roundedTowardZeroInt: Int {
        NSDecimalNumber(decimal: self).intValue
    }
}
