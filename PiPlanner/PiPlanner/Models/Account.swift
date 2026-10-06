import Foundation

/// Spec §3.1 — Account
struct Account: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    /// e.g. "HDFC" or "SBI"
    var bankName: String
    /// e.g. "••4821" or "••7730"
    var maskedNumber: String
    /// Balance in paisa
    var balance: Paisa
    /// true for savings account tracked by app
    var isDedicated: Bool
    /// Demo flag
    var isPaytmLinked: Bool
    /// User's sync consent choice
    var consentAutoUpdate: Bool
}
