import Foundation

/// Shared inflation / savings formulas for goals (PIP-97).
///
/// Pure Swift helpers — not Grok. PIP-98 ledger should call these same APIs so
/// adjusted target and required savings stay identical across create/edit UI and ledger.
///
/// Formulas (brief):
/// - `adjustedTarget = target × (1 + inflation) ^ (monthsStartToEnd / 12)`
/// - `requiredSavings = (adjustedTarget − currentSaving) / monthsRemaining`
enum GoalInflationFormulas {
    /// Default inflation rate — 5% (0.05).
    static let defaultInflationRate = Decimal(string: "0.05")!

    /// Inclusive whole-percent bounds for the inflation rate field (PIP-109).
    static let minInflationPercent = 0
    static let maxInflationPercent = 30

    /// Message when the typed percent is empty, non-numeric, or out of bounds.
    static let invalidInflationPercentMessage =
        "Enter a whole number from \(minInflationPercent) to \(maxInflationPercent)."

    /// Default displayed as a whole percent (5).
    static var defaultInflationPercent: Int {
        displayPercent(fromFraction: defaultInflationRate)
    }

    /// Display percent 0…100 from a 0.0–1.0 fraction.
    static func displayPercent(fromFraction fraction: Decimal) -> Int {
        let percent = (fraction * 100 as NSDecimalNumber).doubleValue
        return Int(percent.rounded())
    }

    /// Parses whole-percent text. Nil if empty, non-numeric, or outside 0…30.
    static func parseInflationPercentText(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber), let value = Int(trimmed) else {
            return nil
        }
        guard value >= minInflationPercent, value <= maxInflationPercent else {
            return nil
        }
        return value
    }

    /// Fraction (0.0–1.0) from a whole percent.
    static func inflationRate(fromPercent percent: Int) -> Decimal {
        Decimal(percent) / 100
    }

    /// Live math rate: valid typed percent, otherwise the 5% default.
    static func effectiveInflationRate(fromPercentText text: String) -> Decimal {
        if let percent = parseInflationPercentText(text) {
            return inflationRate(fromPercent: percent)
        }
        return defaultInflationRate
    }

    // MARK: - Calendar helpers

    /// Whole calendar months from `start` to `end` (non-negative).
    static func monthsBetween(start: Date, end: Date, calendar: Calendar = .gregorianUTC) -> Int {
        let components = calendar.dateComponents([.month], from: start, to: end)
        return max(components.month ?? 0, 0)
    }

    /// Years used in the inflation exponent: `months / 12`.
    static func yearsFromMonths(_ months: Int) -> Double {
        Double(months) / 12.0
    }

    // MARK: - Adjusted target

    /// `target × (1 + inflation) ^ (months from start to end / 12)` — rounded to paisa.
    static func adjustedTargetPaisa(
        targetPaisa: Paisa,
        inflationRate: Decimal,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        let months = monthsBetween(start: startDate, end: endDate, calendar: calendar)
        let years = yearsFromMonths(months)
        let rate = NSDecimalNumber(decimal: inflationRate).doubleValue
        let factor = pow(1 + rate, years)
        return Paisa((Double(targetPaisa) * factor).rounded())
    }

    // MARK: - Required savings (monthly need)

    /// `(adjustedTarget − currentSaving) / monthsRemaining` — rounded via integer division.
    /// When `monthsRemaining` is nil, months are computed from `asOf` → `endDate` (minimum 1).
    static func requiredSavingsPaisa(
        adjustedTarget: Paisa,
        currentSaving: Paisa,
        endDate: Date,
        asOf: Date = Date(),
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        let months = max(monthsBetween(start: asOf, end: endDate, calendar: calendar), 1)
        return requiredSavingsPaisa(
            adjustedTarget: adjustedTarget,
            currentSaving: currentSaving,
            monthsRemaining: months
        )
    }

    /// `(adjustedTarget − currentSaving) / monthsRemaining` with an explicit month count.
    static func requiredSavingsPaisa(
        adjustedTarget: Paisa,
        currentSaving: Paisa,
        monthsRemaining: Int
    ) -> Paisa {
        let months = max(monthsRemaining, 1)
        let remaining = max(adjustedTarget - currentSaving, 0)
        return remaining / Paisa(months)
    }

    /// Alias for UI / existing call sites that say “monthly need”.
    static func monthlyNeedPaisa(
        adjustedTarget: Paisa,
        savedAmount: Paisa,
        endDate: Date,
        asOf: Date = Date(),
        calendar: Calendar = .gregorianUTC
    ) -> Paisa {
        requiredSavingsPaisa(
            adjustedTarget: adjustedTarget,
            currentSaving: savedAmount,
            endDate: endDate,
            asOf: asOf,
            calendar: calendar
        )
    }
}

extension Calendar {
    /// Stable Gregorian calendar for formula tests and ledger alignment.
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
