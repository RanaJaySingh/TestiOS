import Foundation

/// Pending goal parameter edit held until the next credit (PRD R11 / R24, Spec BR-4).
/// Earlier History is never rewritten; UI surfaces toast 9c and held info 13g.
struct HeldGoalChange: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var goalId: UUID
    var savedAt: Date

    var previousName: String
    var pendingName: String
    var previousTargetAmount: Paisa
    var pendingTargetAmount: Paisa
    var previousShareOfNewCredits: Decimal
    var pendingShareOfNewCredits: Decimal
    var previousInflationRate: Decimal
    var pendingInflationRate: Decimal
    var previousStartDate: Date
    var pendingStartDate: Date
    var previousEndDate: Date
    var pendingEndDate: Date

    enum CodingKeys: String, CodingKey {
        case id, goalId, savedAt
        case previousName, pendingName
        case previousTargetAmount, pendingTargetAmount
        case previousShareOfNewCredits, pendingShareOfNewCredits
        case previousInflationRate, pendingInflationRate
        case previousStartDate, pendingStartDate
        case previousEndDate, pendingEndDate
    }

    init(
        id: UUID = UUID(),
        goalId: UUID,
        savedAt: Date,
        previousName: String,
        pendingName: String,
        previousTargetAmount: Paisa,
        pendingTargetAmount: Paisa,
        previousShareOfNewCredits: Decimal,
        pendingShareOfNewCredits: Decimal,
        previousInflationRate: Decimal,
        pendingInflationRate: Decimal,
        previousStartDate: Date,
        pendingStartDate: Date,
        previousEndDate: Date,
        pendingEndDate: Date
    ) {
        self.id = id
        self.goalId = goalId
        self.savedAt = savedAt
        self.previousName = previousName
        self.pendingName = pendingName
        self.previousTargetAmount = previousTargetAmount
        self.pendingTargetAmount = pendingTargetAmount
        self.previousShareOfNewCredits = previousShareOfNewCredits
        self.pendingShareOfNewCredits = pendingShareOfNewCredits
        self.previousInflationRate = previousInflationRate
        self.pendingInflationRate = pendingInflationRate
        self.previousStartDate = previousStartDate
        self.pendingStartDate = pendingStartDate
        self.previousEndDate = previousEndDate
        self.pendingEndDate = pendingEndDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        previousName = try container.decode(String.self, forKey: .previousName)
        pendingName = try container.decode(String.self, forKey: .pendingName)
        previousTargetAmount = try container.decode(Paisa.self, forKey: .previousTargetAmount)
        pendingTargetAmount = try container.decode(Paisa.self, forKey: .pendingTargetAmount)
        previousShareOfNewCredits = try Self.decodeDecimal(from: container, forKey: .previousShareOfNewCredits)
        pendingShareOfNewCredits = try Self.decodeDecimal(from: container, forKey: .pendingShareOfNewCredits)
        previousInflationRate = try Self.decodeDecimal(from: container, forKey: .previousInflationRate)
        pendingInflationRate = try Self.decodeDecimal(from: container, forKey: .pendingInflationRate)
        previousStartDate = try container.decode(Date.self, forKey: .previousStartDate)
        pendingStartDate = try container.decode(Date.self, forKey: .pendingStartDate)
        previousEndDate = try container.decode(Date.self, forKey: .previousEndDate)
        pendingEndDate = try container.decode(Date.self, forKey: .pendingEndDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(goalId, forKey: .goalId)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(previousName, forKey: .previousName)
        try container.encode(pendingName, forKey: .pendingName)
        try container.encode(previousTargetAmount, forKey: .previousTargetAmount)
        try container.encode(pendingTargetAmount, forKey: .pendingTargetAmount)
        try container.encode(
            NSDecimalNumber(decimal: previousShareOfNewCredits).doubleValue,
            forKey: .previousShareOfNewCredits
        )
        try container.encode(
            NSDecimalNumber(decimal: pendingShareOfNewCredits).doubleValue,
            forKey: .pendingShareOfNewCredits
        )
        try container.encode(
            NSDecimalNumber(decimal: previousInflationRate).doubleValue,
            forKey: .previousInflationRate
        )
        try container.encode(
            NSDecimalNumber(decimal: pendingInflationRate).doubleValue,
            forKey: .pendingInflationRate
        )
        try container.encode(previousStartDate, forKey: .previousStartDate)
        try container.encode(pendingStartDate, forKey: .pendingStartDate)
        try container.encode(previousEndDate, forKey: .previousEndDate)
        try container.encode(pendingEndDate, forKey: .pendingEndDate)
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

/// Editable goal fields for frame 6e. `savedAmount` is displayed but locked on save.
struct GoalEditDraft: Equatable, Sendable {
    var name: String
    /// Whole-rupee digit string (same pattern as GoalFormDraft).
    var targetRupeeDigits: String
    var startDate: Date
    var endDate: Date
    var inflationRate: Decimal
    var shareOfNewCredits: Decimal
    /// Read-only on edit; ignored by `GoalHeldChangeService.applyEdit`.
    var savedAmount: Paisa

    var targetPaisa: Paisa {
        GoalValidationService.paisa(fromRupeeDigits: targetRupeeDigits)
    }

    var canSave: Bool {
        GoalValidationService.canSave(
            name: name,
            targetPaisa: targetPaisa,
            startDate: startDate,
            endDate: endDate
        )
    }

    var inflationPercentDisplay: Int {
        GoalValidationService.displayPercent(fromFraction: inflationRate)
    }

    var sharePercentDisplay: Int {
        GoalValidationService.displayPercent(fromFraction: shareOfNewCredits)
    }

    var adjustedTargetPaisa: Paisa {
        GoalValidationService.adjustedTargetPaisa(
            targetPaisa: targetPaisa,
            inflationRate: inflationRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    var monthlyNeedPaisa: Paisa {
        GoalValidationService.monthlyNeedPaisa(
            adjustedTarget: adjustedTargetPaisa,
            savedAmount: savedAmount,
            endDate: endDate
        )
    }

    init(goal: Goal) {
        name = goal.name
        targetRupeeDigits = String(goal.targetAmount / 100)
        startDate = goal.startDate
        endDate = goal.endDate
        inflationRate = goal.inflationRate
        shareOfNewCredits = goal.shareOfNewCredits
        savedAmount = goal.savedAmount
    }

    /// Memberwise init for Goal form → held-edit conversion (PIP-105).
    init(
        name: String,
        targetRupeeDigits: String,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal,
        shareOfNewCredits: Decimal,
        savedAmount: Paisa
    ) {
        self.name = name
        self.targetRupeeDigits = targetRupeeDigits
        self.startDate = startDate
        self.endDate = endDate
        self.inflationRate = inflationRate
        self.shareOfNewCredits = shareOfNewCredits
        self.savedAmount = savedAmount
    }
}

/// Result of committing a goal edit (BR-4).
struct GoalEditCommitResult: Equatable, Sendable {
    var updatedGoal: Goal
    var history: [HistoryEntry]
    var heldChanges: [HeldGoalChange]
    var updatedStandingSplits: [StandingSplit]
    var toastMessage: String
}
