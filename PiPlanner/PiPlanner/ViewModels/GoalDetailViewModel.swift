import Combine
import Foundation

/// Navigation destinations from Goal detail (frame 14).
enum GoalDetailRoute: Hashable, Sendable {
    case edit
    case transfer
    case delete
}

/// View model for Goal detail (frame 14) — PRD R10 / R11.
@MainActor
final class GoalDetailViewModel: ObservableObject {
    @Published private(set) var goal: Goal?
    @Published private(set) var history: [HistoryEntry]
    @Published private(set) var heldChanges: [HeldGoalChange]
    @Published private(set) var standingSplits: [StandingSplit]
    @Published var showToast = false
    @Published private(set) var toastMessage = GoalHeldChangeService.toastMessage
    @Published private(set) var errorMessage: String?
    /// Fallback labels when `goal` is nil (PIP-45 empty destination).
    private let fallbackFormattedSaved: String
    private let fallbackStatusLabel: String

    private let persistence: (any PersistenceServicing)?
    private let formatting: any FormattingServicing
    private let dateFormatter: DateFormatter

    init(
        goal: Goal?,
        formattedSaved: String = "—",
        statusLabel: String = "—",
        history: [HistoryEntry] = [],
        heldChanges: [HeldGoalChange] = [],
        standingSplits: [StandingSplit] = [],
        persistence: (any PersistenceServicing)? = nil,
        formatting: any FormattingServicing = FormattingService()
    ) {
        self.goal = goal
        self.fallbackFormattedSaved = formattedSaved
        self.fallbackStatusLabel = statusLabel
        self.history = history
        self.heldChanges = heldChanges
        self.standingSplits = standingSplits
        self.persistence = persistence
        self.formatting = formatting

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        self.dateFormatter = formatter
    }

    var navigationTitle: String {
        goal?.name ?? "Goal"
    }

    var formattedSaved: String {
        guard let goal else { return fallbackFormattedSaved }
        return formatting.formatINR(paisa: goal.savedAmount)
    }

    var statusLabel: String {
        guard let goal else { return fallbackStatusLabel }
        return GoalHeldChangeService.statusLabel(for: goal.status)
    }

    var formattedAdjustedTarget: String {
        guard let goal else { return "—" }
        return formatting.formatINR(paisa: goal.adjustedTarget)
    }

    var formattedMonthlyNeed: String {
        guard let goal else { return "—" }
        return formatting.formatINR(paisa: goal.monthlyNeed)
    }

    var formattedTarget: String {
        guard let goal else { return "—" }
        return formatting.formatINR(paisa: goal.targetAmount)
    }

    var startDateLabel: String {
        guard let goal else { return "—" }
        return dateFormatter.string(from: goal.startDate)
    }

    var endDateLabel: String {
        guard let goal else { return "—" }
        return dateFormatter.string(from: goal.endDate)
    }

    var inflationLabel: String {
        guard let goal else { return "—" }
        return "\(GoalValidationService.displayPercent(fromFraction: goal.inflationRate))%"
    }

    var shareLabel: String {
        guard let goal else { return "—" }
        return "\(GoalValidationService.displayPercent(fromFraction: goal.shareOfNewCredits))%"
    }

    var hasHeldChange: Bool {
        guard let goal else { return false }
        return GoalHeldChangeService.hasHeldChange(goalId: goal.id, in: heldChanges)
    }

    var heldInfoMessage: String {
        GoalHeldChangeService.heldInfoMessage
    }

    var relatedHistory: [HistoryEntry] {
        guard let goal else { return [] }
        return GoalHeldChangeService.relatedHistory(goalId: goal.id, in: history)
    }

    func formatINR(paisa: Paisa) -> String {
        formatting.formatINR(paisa: paisa)
    }

    func historyTitle(for entry: HistoryEntry) -> String {
        GoalHeldChangeService.historyTypeLabel(for: entry.type)
    }

    func historyAmountLabel(for entry: HistoryEntry) -> String {
        guard let goal,
              let amount = GoalHeldChangeService.amountPaisa(for: entry, goalId: goal.id)
        else {
            return "—"
        }
        return formatting.formatINR(paisa: amount)
    }

    func historyDateLabel(for entry: HistoryEntry) -> String {
        dateFormatter.string(from: entry.createdAt)
    }

    /// Reload from persistence when available (after edit / when opened from Goals tab).
    func refresh() async {
        guard let persistence else { return }
        do {
            let state = try await persistence.loadState()
            history = state.history
            heldChanges = state.heldGoalChanges
            standingSplits = state.standingSplits
            if let goalID = goal?.id {
                goal = state.goals.first { $0.id == goalID } ?? goal
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Apply an edit commit result into local state and show toast (9c).
    func applyEditResult(_ result: GoalEditCommitResult) {
        goal = result.updatedGoal
        history = result.history
        heldChanges = result.heldChanges
        standingSplits = result.updatedStandingSplits
        toastMessage = result.toastMessage
        showToast = true
    }

    func dismissToast() {
        showToast = false
    }
}
