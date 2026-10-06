import Foundation

/// Spec §3.5 — AnalyticsEvent (stub)
enum AnalyticsEvent: Equatable, Sendable {
    case setupStarted
    case setupCompleted(goalCount: Int, openingBalance: Paisa)
    case consentChanged(autoUpdate: Bool)
    case goalCreated(name: String, target: Paisa)
    case goalEdited(goalId: UUID)
    case goalDeleted(goalId: UUID)
    case creditAssigned(amount: Paisa, isTyped: Bool)
    case transferCompleted(amount: Paisa)
    case withdrawalRecorded(amount: Paisa)
    case askQuerySent(query: String)
    case demoReset
}
