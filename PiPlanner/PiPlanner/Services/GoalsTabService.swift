import Foundation

/// Balance-action CTA on the Goals tab balance card (frames 9 / 9b / 9c).
enum GoalsBalanceAction: Equatable, Sendable {
    /// Consent On — Sync button (frame 9b).
    case sync
    /// Consent Off — Update balance (frame 9c).
    case updateBalance
}

/// Pure Goals-tab presentation helpers (PIP-45 / PIP-81 / Spec §4.2 GoalsTabView).
/// Testable on Linux without SwiftUI / Combine.
enum GoalsTabService {
    /// Tab bar labels — Spec §4.3 (no Settings tab).
    static let tabTitles = ["Goals", "History", "Ask"]

    /// Quick-action labels in design order (frame 9).
    static let quickActionTitles = ["Sync", "New goal", "Transfer", "History"]

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

    /// Balance-card primary CTA — "Sync" or "Update balance" (frames 9b / 9c).
    static func balanceActionTitle(for action: GoalsBalanceAction) -> String {
        switch action {
        case .sync:
            return "Sync"
        case .updateBalance:
            return "Update balance"
        }
    }

    /// Quick-action compact label — "Sync" or "Update" (Tech Spec §3.5 QuickActionRow).
    static func quickBalanceActionTitle(for action: GoalsBalanceAction) -> String {
        switch action {
        case .sync:
            return "Sync"
        case .updateBalance:
            return "Update"
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

    /// Newest History `createdAt` as last balance activity (presentation only — no new persistence).
    static func lastBalanceActivityDate(history: [HistoryEntry]) -> Date? {
        history.map(\.createdAt).max()
    }

    /// Navy card footer — "Last synced today, 7:42 pm" / "Last updated …" (R10 / frames 9 / 9c).
    static func lastBalanceActivityLine(
        for action: GoalsBalanceAction,
        referenceDate: Date?,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        let verb: String
        switch action {
        case .sync:
            verb = "Last synced"
        case .updateBalance:
            verb = "Last updated"
        }
        guard let referenceDate else {
            return "\(verb) —"
        }
        return "\(verb) \(relativeDayTimeLabel(referenceDate: referenceDate, now: now, calendar: calendar))"
    }

    /// Goal card primary amount line — "₹60,000 of ₹13,10,796" (frame 9 / 11).
    static func savedOfTargetLabel(
        savedPaisa: Paisa,
        targetPaisa: Paisa,
        formatting: any FormattingServicing
    ) -> String {
        let saved = formatting.formatINR(paisa: savedPaisa)
        let target = formatting.formatINR(paisa: targetPaisa)
        return "\(saved) of \(target)"
    }

    /// Goal card monthly need — "Needs ₹26,058 a month".
    static func monthlyNeedLabel(
        monthlyNeedPaisa: Paisa,
        formatting: any FormattingServicing
    ) -> String {
        "Needs \(formatting.formatINR(paisa: monthlyNeedPaisa)) a month"
    }

    /// Goal card credit share — "60% of credits".
    static func creditsPercentLabel(shareOfNewCredits: Decimal) -> String {
        let percent = GoalValidationService.displayPercent(fromFraction: shareOfNewCredits)
        return "\(percent)% of credits"
    }

    // MARK: - Private

    /// "today, 7:42 pm" / "yesterday, 7:42 pm" / "5 Oct, 7:42 pm".
    private static func relativeDayTimeLabel(
        referenceDate: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        let time = Self.timeFormatter.string(from: referenceDate)
        if calendar.isDate(referenceDate, inSameDayAs: now) {
            return "today, \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(referenceDate, inSameDayAs: yesterday) {
            return "yesterday, \(time)"
        }
        let day = Self.dayFormatter.string(from: referenceDate)
        return "\(day), \(time)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
