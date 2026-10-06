import Foundation

/// Spec §3.1 — StandingSplit
struct StandingSplit: Codable, Equatable, Sendable {
    var goalId: UUID
    /// 0.0–1.0; all must sum to 1.0
    var percentage: Decimal

    enum CodingKeys: String, CodingKey {
        case goalId, percentage
    }

    init(goalId: UUID, percentage: Decimal) {
        self.goalId = goalId
        self.percentage = percentage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        if let doubleValue = try? container.decode(Double.self, forKey: .percentage) {
            percentage = Decimal(doubleValue)
        } else if let stringValue = try? container.decode(String.self, forKey: .percentage),
                  let decimal = Decimal(string: stringValue) {
            percentage = decimal
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .percentage,
                in: container,
                debugDescription: "Expected Decimal-compatible number or string"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalId, forKey: .goalId)
        try container.encode(NSDecimalNumber(decimal: percentage).doubleValue, forKey: .percentage)
    }
}
