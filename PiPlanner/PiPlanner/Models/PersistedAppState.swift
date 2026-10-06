import Foundation

/// Monetary amounts are stored in paisa (`Int64`) per Spec Decisions Log / §4.3.
typealias Paisa = Int64

/// Shared app snapshot persisted locally for the demo (Spec §4.1).
struct PersistedAppState: Codable, Equatable, Sendable {
    var accounts: [Account]
    var goals: [Goal]
    var history: [HistoryEntry]
    var standingSplits: [StandingSplit]

    static let empty = PersistedAppState(
        accounts: [],
        goals: [],
        history: [],
        standingSplits: []
    )
}
