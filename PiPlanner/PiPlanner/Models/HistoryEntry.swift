import Foundation

/// Spec §3.1 — HistoryEntryType
enum HistoryEntryType: String, Codable, CaseIterable, Equatable, Sendable {
    case openingBalance
    case newCredit
    case transfer
    case withdrawal
    case goalDeleted
}

/// Spec §3.1 — GoalAllocation
struct GoalAllocation: Codable, Equatable, Sendable {
    var goalId: UUID
    /// Snapshot at time of entry
    var goalName: String
    /// Amount in paisa
    var amount: Paisa
    /// 0.0–1.0
    var percentage: Decimal

    enum CodingKeys: String, CodingKey {
        case goalId, goalName, amount, percentage
    }

    init(goalId: UUID, goalName: String, amount: Paisa, percentage: Decimal) {
        self.goalId = goalId
        self.goalName = goalName
        self.amount = amount
        self.percentage = percentage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        goalName = try container.decode(String.self, forKey: .goalName)
        amount = try container.decode(Paisa.self, forKey: .amount)
        percentage = try Self.decodeDecimal(from: container, forKey: .percentage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalId, forKey: .goalId)
        try container.encode(goalName, forKey: .goalName)
        try container.encode(amount, forKey: .amount)
        try container.encode(NSDecimalNumber(decimal: percentage).doubleValue, forKey: .percentage)
    }

    private static func decodeDecimal(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Decimal {
        if let doubleValue = try? container.decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        if let stringValue = try? container.decode(String.self, forKey: key),
           let decimal = Decimal(string: stringValue) {
            return decimal
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Expected Decimal-compatible number or string"
        )
    }
}

/// Spec §3.1 — HistoryEntry
struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var type: HistoryEntryType
    var createdAt: Date
    /// true once saved; immutable after
    var isLocked: Bool

    // Credits
    var previousBalance: Paisa?
    var newBalance: Paisa?
    var creditAmount: Paisa?
    /// true if manually typed vs synced
    var isTyped: Bool?

    // Transfers
    var fromGoalId: UUID?
    var toGoalId: UUID?
    var transferAmount: Paisa?

    // Withdrawals
    var withdrawalAmount: Paisa?

    // Deletions
    var deletedGoalName: String?
    var releasedAmount: Paisa?

    /// Allocations (per-goal amounts)
    var allocations: [GoalAllocation]
}
