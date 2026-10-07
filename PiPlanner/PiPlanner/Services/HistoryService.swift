import Foundation

/// Pure History-tab presentation helpers (PIP-59 / frames 12 / 12a).
/// Linux-testable without SwiftUI. Reuses writers’ `HistoryEntry` payloads unchanged.
enum HistoryService {
    /// Read-only caption on locked / opening entries (frame 12a).
    static let originalAmountsCaption = "Original amounts never change"

    /// Empty History tab copy.
    static let emptyStateMessage =
        "No history yet. Opening balance and credits will appear here."

    /// Subtitle for an open New credit row (Assign now).
    static let assignNowSubtitle = CreditEntryService.assignNowTitle

    /// Navigation outcome when a History row is tapped.
    enum Destination: Equatable, Sendable {
        /// Open New credit → editable `CreditEntryView`.
        case editableCredit
        /// Locked / Opening balance → read-only detail.
        case readOnlyDetail
    }

    // MARK: - Ordering

    /// Newest first (frame 12).
    static func sortedNewestFirst(_ history: [HistoryEntry]) -> [HistoryEntry] {
        history.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Labels / icons

    /// Type labels distinguishing entry kinds (AC).
    static func typeLabel(for type: HistoryEntryType) -> String {
        switch type {
        case .openingBalance: return "Opening balance"
        case .newCredit: return "New credit"
        case .transfer: return "Transfer"
        case .withdrawal: return "Withdrawal"
        case .goalDeleted: return "Goal deleted"
        }
    }

    static func typeLabel(for entry: HistoryEntry) -> String {
        typeLabel(for: entry.type)
    }

    /// SF Symbol name for the entry type icon (PIP-71 / Spec §3.3 catalog where applicable).
    static func systemImageName(for type: HistoryEntryType) -> String {
        switch type {
        case .openingBalance: return "banknote"
        case .newCredit: return PiIcons.newCredit
        case .transfer: return PiIcons.transfer
        case .withdrawal: return PiIcons.withdrawal
        case .goalDeleted: return "trash"
        }
    }

    static func systemImageName(for entry: HistoryEntry) -> String {
        systemImageName(for: entry.type)
    }

    // MARK: - Open vs locked / read-only

    /// Saved/locked entries show a lock icon.
    static func showsLockIcon(_ entry: HistoryEntry) -> Bool {
        entry.isLocked
    }

    /// Opening balance is always read-only; any locked entry is read-only.
    static func isReadOnly(_ entry: HistoryEntry) -> Bool {
        entry.type == .openingBalance || entry.isLocked
    }

    /// Open “Assign now” New credit → editable credit entry.
    static func canEditAsCredit(_ entry: HistoryEntry) -> Bool {
        entry.type == .newCredit && !entry.isLocked
    }

    static func destination(for entry: HistoryEntry) -> Destination {
        canEditAsCredit(entry) ? .editableCredit : .readOnlyDetail
    }

    // MARK: - Amounts / subtitles

    /// Primary amount for the list trailing label (paisa).
    static func primaryAmountPaisa(for entry: HistoryEntry) -> Paisa? {
        switch entry.type {
        case .openingBalance:
            return entry.creditAmount ?? entry.newBalance
        case .newCredit:
            return entry.creditAmount
        case .transfer:
            return entry.transferAmount
        case .withdrawal:
            return entry.withdrawalAmount
        case .goalDeleted:
            return entry.releasedAmount
        }
    }

    /// Secondary line under the type label (Assign now / transfer path / deleted name).
    static func rowSubtitle(
        for entry: HistoryEntry,
        goals: [Goal] = [],
        formatting: any FormattingServicing = FormattingService()
    ) -> String? {
        if canEditAsCredit(entry) {
            return assignNowSubtitle
        }
        switch entry.type {
        case .transfer:
            let fromName = goalName(id: entry.fromGoalId, in: goals, fallback: entry.allocations.first?.goalName)
            let toName = goalName(id: entry.toGoalId, in: goals, fallback: entry.allocations.dropFirst().first?.goalName)
            if let amount = entry.transferAmount, let fromName, let toName {
                return TransferService.historyTitle(
                    fromName: fromName,
                    toName: toName,
                    amountPaisa: amount,
                    formatting: formatting
                )
            }
            return nil
        case .goalDeleted:
            if let name = entry.deletedGoalName, !name.isEmpty {
                return name
            }
            return DeleteGoalService.historyTitle
        case .openingBalance, .newCredit, .withdrawal:
            return nil
        }
    }

    private static func goalName(id: UUID?, in goals: [Goal], fallback: String?) -> String? {
        if let id, let match = goals.first(where: { $0.id == id }) {
            return match.name
        }
        return fallback
    }
}
