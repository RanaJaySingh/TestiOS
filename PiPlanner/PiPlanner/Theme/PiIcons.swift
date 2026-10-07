import Foundation

/// SF Symbol catalog for Tech Spec §3.3 icon mapping (A4 — Material metaphor equivalence).
///
/// Linux-testable string names only (no SwiftUI). Call sites use these instead of ad hoc
/// emoji or mismatched glyphs. Weight: outline for unselected tab chrome; filled for selected
/// where an SF filled variant exists.
public enum PiIcons {

    // MARK: - Tab bar (R5 / §3.4)

    /// Goals tab — Material: flag / savings / track_changes.
    public static let goalsTab = "target"
    /// Selected Goals — filled flag matches Material “flag” weight.
    public static let goalsTabSelected = "flag.fill"

    /// History tab — Material: history / schedule.
    public static let historyTab = "clock"
    public static let historyTabSelected = "clock.fill"

    /// Ask tab — Material: chat / forum.
    public static let askTab = "bubble.left.and.bubble.right"
    public static let askTabSelected = "bubble.left.and.bubble.right.fill"

    // MARK: - Actions / chrome

    /// Settings gear — Material: settings (not a tab — A6).
    public static let settings = "gearshape"
    /// Lock on saved / locked history — Material: lock.
    public static let lock = "lock.fill"
    /// Sync — Material: sync.
    public static let sync = "arrow.triangle.2.circlepath"
    /// Transfer — Material: swap_horiz.
    public static let transfer = "arrow.left.arrow.right"
    /// Withdrawal / down — Material: south / arrow_downward.
    public static let withdrawal = "arrow.down.circle"
    /// New credit / add — Material: add_circle.
    public static let newCredit = "plus.circle"

    // MARK: - Header chrome only (A2 / R20) — catalogued for later Goals home chrome

    public static let headerSearch = "magnifyingglass"
    public static let headerNotifications = "bell"
    public static let headerChart = "chart.bar"

    /// Canonical metaphor → SF Symbol pairs for Spec §3.3 smoke tests / Reviewer checklist.
    public static let catalog: [(metaphor: String, systemImage: String)] = [
        ("Goals tab", goalsTab),
        ("History tab", historyTab),
        ("Ask tab", askTab),
        ("Settings gear", settings),
        ("Lock (saved)", lock),
        ("Sync", sync),
        ("Transfer", transfer),
        ("Withdrawal / down", withdrawal),
        ("New credit / add", newCredit),
        ("Header Search", headerSearch),
        ("Header notifications", headerNotifications),
        ("Header chart", headerChart)
    ]
}

/// Tab bar chrome contract (Tech Spec §3.4 / PRD R5) — testable without SwiftUI.
///
/// Exactly three tabs Goals · History · Ask in order. No Settings tab.
public enum MainTabChrome {
    public enum Tab: Int, CaseIterable, Sendable {
        case goals = 0
        case history = 1
        case ask = 2

        public var title: String {
            switch self {
            case .goals: return "Goals"
            case .history: return "History"
            case .ask: return "Ask"
            }
        }

        /// Unselected / default SF Symbol (outline-leaning).
        public var systemImage: String {
            switch self {
            case .goals: return PiIcons.goalsTab
            case .history: return PiIcons.historyTab
            case .ask: return PiIcons.askTab
            }
        }

        /// Selected SF Symbol (filled weight where available).
        public var selectedSystemImage: String {
            switch self {
            case .goals: return PiIcons.goalsTabSelected
            case .history: return PiIcons.historyTabSelected
            case .ask: return PiIcons.askTabSelected
            }
        }

        public var accessibilityIdentifier: String {
            switch self {
            case .goals: return "tab.goals"
            case .history: return "tab.history"
            case .ask: return "tab.ask"
            }
        }

        public func systemImage(selected: Bool) -> String {
            selected ? selectedSystemImage : systemImage
        }
    }

    public static let tabCount = Tab.allCases.count

    public static var titlesInOrder: [String] {
        Tab.allCases.map(\.title)
    }

    /// Selected tab tint uses `DesignTokens.Navy.primary` (via `PiColors.navyPrimary` in UI).
    public static let selectedTintHex = DesignTokens.Navy.primary
}
