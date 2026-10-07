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
    /// Default inflation rate — 7% (0.07).
    static let defaultInflationRate = Decimal(string: "0.07")!

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
