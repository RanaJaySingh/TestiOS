import Foundation

/// Balance-action CTA on the Goals tab balance card (frames 9 / 9b / 9c).
enum GoalsBalanceAction: Equatable, Sendable {
    /// Consent On — Sync button (frame 9b).
    case sync
    /// Consent Off — Update balance (frame 9c).
    case updateBalance
}

/// Pure Goals-tab presentation helpers (PIP-45 / Spec §4.2 GoalsTabView).
/// Testable on Linux without SwiftUI / Combine.
enum GoalsTabService {
    /// Tab bar labels — Spec §4.3 (no Settings tab).
    static let tabTitles = ["Goals", "History", "Ask"]

    /// Status copy matching design frames 9 / 11.
    static func statusLabel(for status: GoalStatus) -> String {
        switch status {
        case .onTrack:
            return "On track"
        case .behind:
            return "Behind"
        }
    }

    /// Total savings shown on the balance card.
    /// Prefers dedicated account balance (PRD R21); falls back to sum of goal `savedAmount`.
    static func totalSavingsPaisa(accounts: [Account], goals: [Goal]) -> Paisa {
        if let dedicated = AccountsService.dedicatedAccount(in: accounts) {
            return dedicated.balance
        }
        return goals.reduce(Paisa(0)) { $0 + $1.savedAmount }
    }

    /// Consent from the dedicated account drives Sync vs Update balance.
    static func balanceAction(for accounts: [Account]) -> GoalsBalanceAction {
        if let dedicated = AccountsService.dedicatedAccount(in: accounts),
           dedicated.consentAutoUpdate {
            return .sync
        }
        return .updateBalance
    }

    static func balanceActionTitle(for action: GoalsBalanceAction) -> String {
        switch action {
        case .sync:
            return "Sync"
        case .updateBalance:
            return "Update balance"
        }
    }

    /// Account subtitle for the balance card (bank + masked number).
    static func dedicatedAccountSubtitle(accounts: [Account]) -> String? {
        guard let dedicated = AccountsService.dedicatedAccount(in: accounts) else {
            return nil
        }
        return AccountsService.displayTitle(for: dedicated)
    }

    /// Whether the Goals tab has goal cards to show (post-setup with goals).
    static func hasGoals(_ goals: [Goal]) -> Bool {
        !goals.isEmpty
    }
}
