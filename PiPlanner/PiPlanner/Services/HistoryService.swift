import Foundation

/// Pure History-tab presentation helpers (PIP-59 / PIP-104 / frames 12 / 12a).
/// Linux-testable without SwiftUI. Reuses tip ledger `HistoryEntry` payloads unchanged.
///
/// PIP-104: newest-first list of saved/locked entries (read-only) plus open Assign-now
/// credit; Typed / Custom list chips; open vs saved destination via tip `LedgerEngine` /
/// `CreditEntryService` open-credit discovery (keep-both with PIP-102/103).
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

    /// List-row chips for New credit variants (PRD J6: Typed / Custom split).
    enum RowBadge: String, Equatable, Sendable, CaseIterable {
        case typed = "Typed"
        case custom = "Custom"
    }

    // MARK: - Ordering

    /// Newest first (frame 12 / PIP-104).
    static func sortedNewestFirst(_ history: [HistoryEntry]) -> [HistoryEntry] {
        history.sorted { $0.createdAt > $1.createdAt }
    }

    /// Saved/locked entries only (read-only list slice). Open Assign-now credits are
    /// still shown in the full tab list via `sortedNewestFirst`.
    static func savedEntries(in history: [HistoryEntry]) -> [HistoryEntry] {
        sortedNewestFirst(history.filter { $0.isLocked || $0.type == .openingBalance })
    }

    /// Open (unlocked) New credit, if any — tip ledger discovery (PIP-102/103/98).
    static func openCreditEntry(in history: [HistoryEntry]) -> HistoryEntry? {
        CreditEntryService.openCreditEntry(in: history)
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

    /// List type label (PRD J6): distinguishes Custom split / Typed among New credits
    /// while keeping Opening / Transfer / Withdrawal / Goal deleted labels unchanged.
    static func listTypeLabel(for entry: HistoryEntry) -> String {
        guard entry.type == .newCredit else {
            return typeLabel(for: entry)
        }
        if showsCustomSplitBadge(entry) {
            return "Custom split"
        }
        if showsTypedBadge(entry) {
            return "Typed"
        }
        return typeLabel(for: entry)
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

    /// Typed badge on New credit (synced vs typed — frame 13t).
    static func showsTypedBadge(_ entry: HistoryEntry) -> Bool {
        entry.type == .newCredit && entry.isTyped == true
    }

    /// Custom-split badge when the saved this-credit % differs from suggested standing (PIP-103).
    static func showsCustomSplitBadge(_ entry: HistoryEntry) -> Bool {
        entry.type == .newCredit && entry.customSplit == true
    }

    /// List-row chips (PRD J6 / PIP-104). Custom wins over Typed for the primary
    /// `listTypeLabel`; both may still appear as chips on locked credits.
    static func rowBadges(for entry: HistoryEntry) -> [RowBadge] {
        guard entry.type == .newCredit else { return [] }
        var badges: [RowBadge] = []
        if showsTypedBadge(entry) { badges.append(.typed) }
        if showsCustomSplitBadge(entry) { badges.append(.custom) }
        return badges
    }

    /// Titles for list chips. Omits a chip when `listTypeLabel` already names that
    /// variant (e.g. "Custom split" → no "Custom" chip); keeps the other when both apply.
    static func rowBadgeTitles(for entry: HistoryEntry) -> [String] {
        let label = listTypeLabel(for: entry)
        return rowBadges(for: entry).compactMap { badge in
            switch badge {
            case .custom where label == "Custom split":
                return nil
            case .typed where label == "Typed":
                return nil
            default:
                return badge.rawValue
            }
        }
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
