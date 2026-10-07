import Combine
import Foundation

/// View model for open / locked New credit History entry (frames 13 / 13a–13g / 13t).
/// PRD R7–R8; Spec BR-2, BR-5.
@MainActor
final class CreditEntryViewModel: ObservableObject {
    @Published private(set) var displayPercents: [UUID: Int]
    @Published var useThisSplitForStanding = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var entry: HistoryEntry
    @Published private(set) var goals: [Goal]

    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date

    var isSingleGoal: Bool { goals.count == 1 }
    var isLocked: Bool { entry.isLocked }
    var isTyped: Bool { entry.isTyped == true }

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
        clock: @escaping () -> Date = Date.init
    ) {
        self.entry = entry
        self.goals = goals
        self.persistence = persistence
        self.formatting = formatting
        self.clock = clock

        if goals.count == 1, let goal = goals.first {
            self.displayPercents = [goal.id: 100]
        } else {
            self.displayPercents = Dictionary(uniqueKeysWithValues: entry.allocations.map {
                ($0.goalId, ($0.percentage * 100).roundedTowardZeroInt)
            })
            // Ensure every current goal has a key.
            for goal in goals where displayPercents[goal.id] == nil {
                displayPercents[goal.id] = 0
            }
        }
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

    /// BR-5 / R8: Save and lock once; optional standing split update.
    func saveAndLock() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state = try await persistence.loadState()
            state = try CreditEntryService.applyCreditLock(
                to: state,
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
