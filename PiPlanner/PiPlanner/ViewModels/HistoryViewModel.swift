import Combine
import Foundation

/// View model for History tab (frames 12 / 12a) — PIP-59 / PIP-104.
///
/// Loads tip ledger history; open Assign-now → editable credit; saved/locked →
/// read-only detail. Open-credit discovery uses injected `LedgerEngine`
/// (default `StubLedgerEngine`) — keep-both with Goals Sync/Update (PIP-102).
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Open credit presented for assignment from History.
    @Published private(set) var activeCreditEntry: HistoryEntry?
    @Published var showCreditEntry = false
    /// Tip ledger open New credit (if any), for banner/tests — same source as Goals.
    @Published private(set) var openCreditEntry: HistoryEntry?

    let persistence: any PersistenceServicing
    let formatting: any FormattingServicing
    let ledger: any LedgerEngine

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(
        persistence: any PersistenceServicing,
        formatting: any FormattingServicing = FormattingService(),
        ledger: any LedgerEngine = StubLedgerEngine(),
        initialState: PersistedAppState? = nil
    ) {
        self.persistence = persistence
        self.formatting = formatting
        self.ledger = ledger
        if let initialState {
            apply(initialState)
        }
    }

    var isEmpty: Bool { entries.isEmpty }

    var emptyStateMessage: String { HistoryService.emptyStateMessage }

    var originalAmountsCaption: String { HistoryService.originalAmountsCaption }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let state = try await persistence.loadState()
            apply(state)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func presentCreditEntry(_ entry: HistoryEntry) {
        guard HistoryService.canEditAsCredit(entry) else { return }
        activeCreditEntry = entry
        showCreditEntry = true
    }

    func creditEntryFinished() {
        showCreditEntry = false
        activeCreditEntry = nil
        Task { await load() }
    }

    func destination(for entry: HistoryEntry) -> HistoryService.Destination {
        HistoryService.destination(for: entry)
    }

    func typeLabel(for entry: HistoryEntry) -> String {
        HistoryService.listTypeLabel(for: entry)
    }

    func systemImageName(for entry: HistoryEntry) -> String {
        HistoryService.systemImageName(for: entry)
    }

    func showsLockIcon(for entry: HistoryEntry) -> Bool {
        HistoryService.showsLockIcon(entry)
    }

    func rowBadgeTitles(for entry: HistoryEntry) -> [String] {
        HistoryService.rowBadgeTitles(for: entry)
    }

    func amountLabel(for entry: HistoryEntry) -> String {
        guard let amount = HistoryService.primaryAmountPaisa(for: entry) else {
            return "—"
        }
        return formatting.formatINR(paisa: amount)
    }

    func dateLabel(for entry: HistoryEntry) -> String {
        dateFormatter.string(from: entry.createdAt)
    }

    func rowSubtitle(for entry: HistoryEntry) -> String? {
        HistoryService.rowSubtitle(for: entry, goals: goals, formatting: formatting)
    }

    func entry(id: UUID) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    private func apply(_ state: PersistedAppState) {
        goals = state.goals
        entries = HistoryService.sortedNewestFirst(state.history)
        openCreditEntry = ledger.openCreditEntry(in: state.history)
    }
}
