import Foundation

/// Spec §3.3 — BalanceSyncService (mock for local demo).
protocol BalanceSyncServicing: Sendable {
    /// Mock: returns seeded demo balance for a known account.
    func fetchBalance(accountId: UUID) async -> Result<Paisa, SyncError>
    /// Mock: succeeds only with demo PIN `"1234"`.
    func verifyUPIPin(pin: String) async -> Result<Paisa, PinError>
}

/// Demo Balance sync used by Consent Yes / UPI PIN paths (PRD R3 / R4).
struct MockBalanceSyncService: BalanceSyncServicing {
    /// Demo UPI PIN accepted by the mock pad (Spec §4.3).
    static let demoPIN = "1234"
    /// Seeded opening balance — ₹1,00,000 (PRD R3 / persona).
    static let demoBalancePaisa: Paisa = 10_000_000
    /// Demo credit after Sync — ₹1,10,000 (₹10,000 new credit for PIP-47 demos).
    static let demoHigherBalancePaisa: Paisa = 11_000_000

    /// When non-empty, `fetchBalance` fails for unknown IDs with `.accountNotFound`.
    var knownAccountIDs: Set<UUID>
    /// Optional override for Sync/Update demos and tests (higher / same / lower).
    var fetchedBalancePaisa: Paisa

    init(
        knownAccountIDs: Set<UUID> = [],
        fetchedBalancePaisa: Paisa = MockBalanceSyncService.demoBalancePaisa
    ) {
        self.knownAccountIDs = knownAccountIDs
        self.fetchedBalancePaisa = fetchedBalancePaisa
    }

    func fetchBalance(accountId: UUID) async -> Result<Paisa, SyncError> {
        if !knownAccountIDs.isEmpty, !knownAccountIDs.contains(accountId) {
            return .failure(.accountNotFound)
        }
        return .success(fetchedBalancePaisa)
    }

    func verifyUPIPin(pin: String) async -> Result<Paisa, PinError> {
        if pin == Self.demoPIN {
            return .success(fetchedBalancePaisa)
        }
        return .failure(.wrongPin)
    }

    /// Frame 4c — account registered on another UPI app (forces manual entry).
    func accountOnOtherUPIApp() -> PinError {
        .otherApp
    }
}

/// Pure helpers for Consent / manual balance entry (PRD R3 / R4).
enum ConsentService {
    /// Consent sheet bullets (design frame 3 / PRD R3).
    static let consentBullets: [String] = [
        "Reads only this account’s balance",
        "Stores the last balance we checked",
        "Never sends statements, payees, UPI IDs, or account numbers to Grok",
        "You can change this anytime in Settings"
    ]

    /// Continue on Manual amount (4a) is disabled at ₹0.
    static func canContinueManual(amountPaisa: Paisa) -> Bool {
        amountPaisa > 0
    }

    /// Parses whole-rupee digit string into paisa. Non-digits ignored; empty → 0.
    static func paisa(fromRupeeDigits digits: String) -> Paisa {
        let filtered = digits.filter(\.isNumber)
        guard !filtered.isEmpty, let rupees = Paisa(filtered) else { return 0 }
        return rupees * 100
    }

    static func isCompletePIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }
}
