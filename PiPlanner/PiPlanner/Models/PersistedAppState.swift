import Foundation

/// Monetary amounts are stored in paisa (`Int64`) per Spec Decisions Log / §4.3.
typealias Paisa = Int64

/// Shared app snapshot persisted locally for the demo (Spec §4.1).
struct PersistedAppState: Codable, Equatable, Sendable {
    var accounts: [Account]
    var goals: [Goal]
    var history: [HistoryEntry]
    var standingSplits: [StandingSplit]
    /// Goal edits held until next credit (PRD R11 / R24, Spec BR-4). Optional for older saves.
    var heldGoalChanges: [HeldGoalChange]

    static let empty = PersistedAppState(
        accounts: [],
        goals: [],
        history: [],
        standingSplits: [],
        heldGoalChanges: []
    )

    init(
        accounts: [Account],
        goals: [Goal],
        history: [HistoryEntry],
        standingSplits: [StandingSplit],
        heldGoalChanges: [HeldGoalChange] = []
    ) {
        self.accounts = accounts
        self.goals = goals
        self.history = history
        self.standingSplits = standingSplits
        self.heldGoalChanges = heldGoalChanges
    }

    enum CodingKeys: String, CodingKey {
        case accounts, goals, history, standingSplits, heldGoalChanges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decode([Account].self, forKey: .accounts)
        goals = try container.decode([Goal].self, forKey: .goals)
        history = try container.decode([HistoryEntry].self, forKey: .history)
        standingSplits = try container.decode([StandingSplit].self, forKey: .standingSplits)
        heldGoalChanges = try container.decodeIfPresent([HeldGoalChange].self, forKey: .heldGoalChanges) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(goals, forKey: .goals)
        try container.encode(history, forKey: .history)
        try container.encode(standingSplits, forKey: .standingSplits)
        try container.encode(heldGoalChanges, forKey: .heldGoalChanges)
    }
}
