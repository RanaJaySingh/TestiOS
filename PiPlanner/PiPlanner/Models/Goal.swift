import Foundation

/// Spec §3.1 — GoalStatus (computed)
enum GoalStatus: Equatable, Sendable {
    case onTrack
    /// Shortfall in paisa
    case behind(shortfall: Paisa)
}

/// Spec §3.1 — Goal
struct Goal: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// e.g. "Car", "Emergency Fund"
    var name: String
    /// Target in paisa
    var targetAmount: Paisa
    var startDate: Date
    var endDate: Date
    /// Default 5% (0.05)
    var inflationRate: Decimal
    /// Locked amount in paisa
    var savedAmount: Paisa
    /// Standing split % (0.0–1.0)
    var shareOfNewCredits: Decimal
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Computed (Spec §3.1 / PIP-97)

    /// `target × (1 + inflation) ^ (monthsStartToEnd / 12)` — see `GoalInflationFormulas`.
    var adjustedTarget: Paisa {
        GoalInflationFormulas.adjustedTargetPaisa(
            targetPaisa: targetAmount,
            inflationRate: inflationRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    /// Required monthly savings — see `GoalInflationFormulas.requiredSavingsPaisa`.
    var monthlyNeed: Paisa {
        GoalInflationFormulas.requiredSavingsPaisa(
            adjustedTarget: adjustedTarget,
            currentSaving: savedAmount,
            endDate: endDate
        )
    }

    /// OnTrack | Behind(shortfall)
    var status: GoalStatus {
        let months = GoalInflationFormulas.monthsBetween(start: startDate, end: Date())
        let expectedSaved = monthlyNeed * Paisa(months)
        if savedAmount >= expectedSaved {
            return .onTrack
        }
        return .behind(shortfall: expectedSaved - savedAmount)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, targetAmount, startDate, endDate
        case inflationRate, savedAmount, shareOfNewCredits, createdAt, updatedAt
    }

    init(
        id: UUID,
        name: String,
        targetAmount: Paisa,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal,
        savedAmount: Paisa,
        shareOfNewCredits: Decimal,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.endDate = endDate
        self.inflationRate = inflationRate
        self.savedAmount = savedAmount
        self.shareOfNewCredits = shareOfNewCredits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetAmount = try container.decode(Paisa.self, forKey: .targetAmount)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        inflationRate = try Self.decodeDecimal(from: container, forKey: .inflationRate)
        savedAmount = try container.decode(Paisa.self, forKey: .savedAmount)
        shareOfNewCredits = try Self.decodeDecimal(from: container, forKey: .shareOfNewCredits)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(targetAmount, forKey: .targetAmount)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(NSDecimalNumber(decimal: inflationRate).doubleValue, forKey: .inflationRate)
        try container.encode(savedAmount, forKey: .savedAmount)
        try container.encode(NSDecimalNumber(decimal: shareOfNewCredits).doubleValue, forKey: .shareOfNewCredits)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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
