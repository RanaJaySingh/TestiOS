import Combine
import Foundation

/// View model for Withdrawal flow (frames 18 / 18a / 18b / 18c) — PRD R15, Spec BR-8.
@MainActor
final class WithdrawalViewModel: ObservableObject {
    @Published private(set) var phase: WithdrawalService.Phase
    @Published private(set) var goals: [Goal]
    /// Reduction amounts in paisa keyed by goal id.
    @Published private(set) var reductions: [UUID: Paisa]
    /// Rupee digit strings while editing (whole rupees).
    @Published var editRupeeDigits: [UUID: String] = [:]
    /// After the user finishes one edit pass, reductions lock until Save.
    @Published private(set) var hasEditedOnce = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSave = false
    @Published private(set) var isComplete = false

    let shortfall: Paisa
    let previousBalance: Paisa
    let newBalance: Paisa
    /// True when opened via "Record a withdrawal" (18c) rather than Sync lower (10b).
    let isManualRecord: Bool

    private let persistence: any PersistenceServicing
    private let formatting: any FormattingServicing
    private let clock: () -> Date
    private let makeID: () -> UUID
    private let onSaved: (() -> Void)?

    init(
        shortfall: Paisa,
        previousBalance: Paisa,
        newBalance: Paisa,
        goals: [Goal],
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        isManualRecord: Bool = false,
        clock: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init,
        onSaved: (() -> Void)? = nil
    ) {
        self.shortfall = shortfall
        self.previousBalance = previousBalance
        self.newBalance = newBalance
        self.goals = goals
        self.persistence = persistence
        self.formatting = formatting
        self.isManualRecord = isManualRecord
        self.clock = clock
        self.makeID = makeID
        self.onSaved = onSaved

        let defaults = WithdrawalService.proportionalReductions(goals: goals, shortfall: shortfall)
        self.reductions = defaults
        self.phase = .proportionalDefault
        self.editRupeeDigits = Dictionary(
            uniqueKeysWithValues: goals.map { goal in
                (goal.id, String((defaults[goal.id] ?? 0) / 100))
            }
        )
    }

    var formattedShortfall: String {
        formatting.formatINR(paisa: shortfall)
    }

    var formattedPrevious: String {
        formatting.formatINR(paisa: previousBalance)
    }

    var formattedNewBalance: String {
        formatting.formatINR(paisa: newBalance)
    }

    var totalAssigned: Paisa {
        WithdrawalService.totalReductions(reductions, goals: goals)
    }

    var formattedTotalAssigned: String {
        formatting.formatINR(paisa: totalAssigned)
    }

    var isEditing: Bool { phase == .edit }

    var canStartEdit: Bool {
        !hasEditedOnce && !isComplete && (phase == .proportionalDefault || phase == .invalidTotal || phase == .goalBelowZero)
    }

    var canSave: Bool {
        !isSaving
            && !isComplete
            && phase != .edit
            && WithdrawalService.canSave(
                reductions: reductions,
                goals: goals,
                shortfall: shortfall
            )
    }

    var caption: String {
        isManualRecord
            ? WithdrawalService.manualRecordCaption
            : WithdrawalService.proportionalCaption
    }

    var statusMessage: String {
        if isComplete {
            return "Withdrawal locked. History entry saved."
        }
        let liveTotal: Paisa = {
            if phase == .edit {
                return goals.map { previewReduction(for: $0) }.reduce(0, +)
            }
            return totalAssigned
        }()
        if phase == .edit {
            if let invalid = WithdrawalService.invalidTotalMessage(
                totalAssigned: liveTotal,
                shortfall: shortfall,
                formatting: formatting
            ) {
                return invalid
            }
            return "Total \(formatting.formatINR(paisa: liveTotal)). Edit once, then Done."
        }
        if let bad = WithdrawalService.firstGoalBelowZero(reductions: reductions, goals: goals) {
            return WithdrawalService.goalBelowZeroMessage(goal: bad)
        }
        if let invalid = WithdrawalService.invalidTotalMessage(
            totalAssigned: totalAssigned,
            shortfall: shortfall,
            formatting: formatting
        ) {
            return invalid
        }
        return hasEditedOnce
            ? "Total \(formattedTotalAssigned). Ready to Save and lock."
            : "Total \(formattedTotalAssigned). Proportional default — edit once or Save and lock."
    }

    func formattedReduction(for goalID: UUID, previewing: Bool = false) -> String {
        let amount: Paisa
        if previewing, let goal = goals.first(where: { $0.id == goalID }) {
            amount = previewReduction(for: goal)
        } else {
            amount = reductions[goalID] ?? 0
        }
        return formatting.formatINR(paisa: amount)
    }

    func formattedSaved(for goal: Goal) -> String {
        formatting.formatINR(paisa: goal.savedAmount)
    }

    func afterWithdrawalSaved(for goal: Goal, previewing: Bool = false) -> String {
        let reduction = previewing ? previewReduction(for: goal) : (reductions[goal.id] ?? 0)
        let next = max(goal.savedAmount - reduction, 0)
        return formatting.formatINR(paisa: next)
    }

    func beginEdit() {
        guard canStartEdit else { return }
        phase = .edit
        errorMessage = nil
        editRupeeDigits = Dictionary(
            uniqueKeysWithValues: goals.map { goal in
                (goal.id, String((reductions[goal.id] ?? 0) / 100))
            }
        )
    }

    func finishEdit() {
        guard phase == .edit else { return }
        applyEditDigitsToReductions()
        refreshPhaseAfterEdit()
        hasEditedOnce = true
        errorMessage = nil
    }

    func setEditRupeeDigits(goalID: UUID, digits: String) {
        guard phase == .edit, !hasEditedOnce else { return }
        editRupeeDigits[goalID] = digits.filter(\.isNumber)
        errorMessage = nil
    }

    /// Live preview while editing — clamps per-goal so UI never proposes below ₹0.
    func previewReduction(for goal: Goal) -> Paisa {
        guard phase == .edit else { return reductions[goal.id] ?? 0 }
        let digits = editRupeeDigits[goal.id] ?? "0"
        let rupees = Paisa(digits) ?? 0
        return WithdrawalService.clampedReduction(amount: rupees * 100, for: goal)
    }

    func saveAndLock() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            var state = try await persistence.loadState()
            if state.goals.isEmpty {
                state.goals = goals
            }
            state = try WithdrawalService.applyWithdrawal(
                to: state,
                shortfall: shortfall,
                previousBalance: previousBalance,
                newBalance: newBalance,
                reductions: reductions,
                entryID: makeID(),
                now: clock()
            )
            try await persistence.saveState(state)
            goals = state.goals
            isComplete = true
            phase = .complete
            didSave = true
            onSaved?()
        } catch let error as AppError {
            errorMessage = error.localizedDescription
            refreshPhaseAfterEdit()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyEditDigitsToReductions() {
        var next: [UUID: Paisa] = [:]
        for goal in goals {
            let digits = editRupeeDigits[goal.id] ?? "0"
            let rupees = Paisa(digits) ?? 0
            next[goal.id] = WithdrawalService.clampedReduction(amount: rupees * 100, for: goal)
        }
        reductions = next
    }

    private func refreshPhaseAfterEdit() {
        if isComplete {
            phase = .complete
            return
        }
        if WithdrawalService.firstGoalBelowZero(reductions: reductions, goals: goals) != nil {
            phase = .goalBelowZero
        } else if totalAssigned != shortfall {
            phase = .invalidTotal
        } else {
            phase = .proportionalDefault
        }
    }
}
