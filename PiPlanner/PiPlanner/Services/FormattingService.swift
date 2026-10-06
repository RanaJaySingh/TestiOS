import Foundation

/// Formats amounts for display (Spec BR-10 / PRD R20).
protocol FormattingServicing: Sendable {
    /// Formats paisa as Indian-grouped rupees with ₹ (no paise unless design requires).
    func formatINR(paisa: Paisa) -> String
}

/// Spec §4.2 / §4.3 — FormattingService
struct FormattingService: FormattingServicing {
    func formatINR(paisa: Paisa) -> String {
        let negative = paisa < 0
        let rupees = abs(paisa) / 100
        let grouped = Self.indianGroupedString(for: rupees)
        return negative ? "-₹\(grouped)" : "₹\(grouped)"
    }

    /// Indian numbering: last three digits, then groups of two (e.g. 13,10,796).
    private static func indianGroupedString(for rupees: Paisa) -> String {
        let digits = String(rupees)
        guard digits.count > 3 else {
            return digits
        }

        let characters = Array(digits)
        let splitIndex = characters.count - 3
        let head = Array(characters[..<splitIndex])
        let tail = String(characters[splitIndex...])

        var groups: [String] = []
        var index = head.count
        while index > 0 {
            let start = max(index - 2, 0)
            groups.insert(String(head[start..<index]), at: 0)
            index = start
        }

        return (groups + [tail]).joined(separator: ",")
    }
}
