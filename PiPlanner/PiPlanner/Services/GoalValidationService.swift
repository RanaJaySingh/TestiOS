import Foundation

/// Pure validation + inflation helpers for Goal form / chat (PRD R5, Spec §3.4).
enum GoalValidationService {
    /// Default inflation rate — 7% (PRD R5 / frame 7).
    static let defaultInflationRate = Decimal(string: "0.07")!

    /// Proposal / defined-goals footer label (frame 5b).
    static let checkedByLabel = StubGrokService.checkedByLabel

    /// Max vague-input follow-ups before forcing the form (PRD R5 / frame 5a).
    static let maxFollowUps = 2

    // MARK: - Form field validation

    static func isNameValid(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isTargetValid(_ targetPaisa: Paisa) -> Bool {
        targetPaisa > 0
    }

    static func areDatesValid(start: Date, end: Date) -> Bool {
        end > start
    }

    /// Save enabled only when name non-empty, target > ₹0, and end after start.
    static func canSave(
        name: String,
        targetPaisa: Paisa,
        startDate: Date,
        endDate: Date
    ) -> Bool {
        isNameValid(name) && isTargetValid(targetPaisa) && areDatesValid(start: startDate, end: endDate)
    }

    /// Spec §3.4 ValidationError list for invalid form drafts.
    static func validationErrors(
        name: String,
        targetPaisa: Paisa,
        startDate: Date,
        endDate: Date
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        if !isNameValid(name) {
            errors.append(
                ValidationError(
                    field: "name",
                    message: "Name is required.",
                    code: .emptyName
                )
            )
        }
        if !isTargetValid(targetPaisa) {
            errors.append(
                ValidationError(
                    field: "targetAmount",
                    message: "Target must be greater than ₹0.",
                    code: .zeroTarget
                )
            )
        }
        if !areDatesValid(start: startDate, end: endDate) {
            errors.append(
                ValidationError(
                    field: "endDate",
                    message: "End date must be after start date.",
                    code: .endNotAfterStart
                )
            )
        }
        return errors
    }

    // MARK: - Split gating (goals defined → Continue)

    /// Continue into Opening split when defined goals’ shares sum to 100%.
    static func canContinueWithDefinedGoals(_ goals: [Goal]) -> Bool {
        guard !goals.isEmpty else { return false }
        let fractions = goals.map(\.shareOfNewCredits)
        return OpeningSplitService.isValidHundredPercent(fractions)
    }

    static func splitShortfallMessage(for goals: [Goal]) -> String? {
        OpeningSplitService.shortfallMessage(for: goals.map(\.shareOfNewCredits))
    }

    // MARK: - Inflation / targets

    /// `targetAmount * (1 + inflationRate)^years` — same rule as `Goal.adjustedTarget`.
    static func adjustedTargetPaisa(
        targetPaisa: Paisa,
        inflationRate: Decimal,
        startDate: Date,
        endDate: Date
    ) -> Paisa {
        let years = max(yearsBetween(start: startDate, end: endDate), 0)
        let factor = pow(1 + NSDecimalNumber(decimal: inflationRate).doubleValue, years)
        return Paisa((Double(targetPaisa) * factor).rounded())
    }

    /// `(adjustedTarget - savedAmount) / monthsRemaining`
    static func monthlyNeedPaisa(
        adjustedTarget: Paisa,
        savedAmount: Paisa,
        endDate: Date,
        asOf: Date = Date()
    ) -> Paisa {
        let months = max(monthsBetween(start: asOf, end: endDate), 1)
        let remaining = max(adjustedTarget - savedAmount, 0)
        return remaining / Paisa(months)
    }

    /// Parses whole-rupee digit string into paisa. Non-digits ignored; empty → 0.
    static func paisa(fromRupeeDigits digits: String) -> Paisa {
        let filtered = digits.filter(\.isNumber)
        guard !filtered.isEmpty, let rupees = Paisa(filtered) else { return 0 }
        return rupees * 100
    }

    /// Display percent 0…100 from a 0.0–1.0 fraction.
    static func displayPercent(fromFraction fraction: Decimal) -> Int {
        let percent = (fraction * 100 as NSDecimalNumber).doubleValue
        return Int(percent.rounded())
    }

    /// Builds a Goal from validated form fields (saved starts at ₹0 in create).
    static func makeGoal(
        id: UUID = UUID(),
        name: String,
        targetPaisa: Paisa,
        startDate: Date,
        endDate: Date,
        inflationRate: Decimal = defaultInflationRate,
        shareOfNewCredits: Decimal,
        savedAmount: Paisa = 0,
        now: Date = Date()
    ) -> Goal {
        Goal(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: targetPaisa,
            startDate: startDate,
            endDate: endDate,
            inflationRate: inflationRate,
            savedAmount: savedAmount,
            shareOfNewCredits: shareOfNewCredits,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Converts confirmed proposals into Goals with default dates / inflation.
    static func goals(from proposals: [GoalProposal], now: Date = Date()) -> [Goal] {
        let end = now.addingTimeInterval(86_400 * 365)
        return proposals.map { proposal in
            makeGoal(
                id: proposal.id,
                name: proposal.name,
                targetPaisa: proposal.suggestedTarget ?? 1_000_000,
                startDate: now,
                endDate: end,
                inflationRate: defaultInflationRate,
                shareOfNewCredits: proposal.sharePercentage,
                savedAmount: 0,
                now: now
            )
        }
    }

    private static func yearsBetween(start: Date, end: Date) -> Double {
        let seconds = end.timeIntervalSince(start)
        return max(seconds / (365.25 * 24 * 60 * 60), 0)
    }

    private static func monthsBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.month], from: start, to: end)
        return max(components.month ?? 0, 0)
    }
}
