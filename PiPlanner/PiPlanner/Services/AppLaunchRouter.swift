import Foundation

/// Root destination after load / Reset demo (PRD R1 / R17).
enum AppLaunchDestination: Equatable, Sendable {
    /// First-run or post–Reset demo — Welcome (frame 1).
    case welcome
    /// Setup completed (locked Opening balance) — Goals tab (or placeholder).
    case goals
}

/// Pure routing for app launch. Testable without UIKit/SwiftUI.
enum AppLaunchRouter {
    /// First-run and post–Reset demo both yield empty goals + history
    /// (`PersistenceService.resetDemo` clears the JSON file → `.empty`).
    static func destination(for state: PersistedAppState) -> AppLaunchDestination {
        if hasCompletedSetup(state) {
            return .goals
        }
        return .welcome
    }

    /// Setup is complete once an Opening balance History entry exists (R6).
    static func hasCompletedSetup(_ state: PersistedAppState) -> Bool {
        state.history.contains { $0.type == .openingBalance && $0.isLocked }
    }

    /// Explicit first-run / post-reset check used by tests and Reset wiring.
    static func isFirstRunOrPostReset(_ state: PersistedAppState) -> Bool {
        state.goals.isEmpty && state.history.isEmpty
    }
}
