import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class LedgerFacadeTests: XCTestCase {
    func testApplySetupOpeningBalanceUpdatesDedicatedOnly() {
        let accounts = [
            sampleHDFC(isDedicated: true, balance: 5_000_000, consent: false),
            sampleSBI(isDedicated: false, balance: 7_200_000)
        ]

        let updated = LedgerFacade.applySetupOpeningBalance(
            to: accounts,
            balancePaisa: 10_000_000,
            consentAutoUpdate: true,
            source: .snapshotFetch
        )

        XCTAssertEqual(updated[0].balance, 10_000_000)
        XCTAssertTrue(updated[0].consentAutoUpdate)
        XCTAssertEqual(updated[1].balance, 7_200_000, "Spending balance stays untouched")
        XCTAssertFalse(updated[1].consentAutoUpdate)
    }

    func testApplySetupOpeningBalanceTypedSourceDoesNotTouchSpending() {
        let accounts = [
            sampleHDFC(isDedicated: true, balance: 0, consent: false),
            sampleSBI(isDedicated: false, balance: 7_200_000)
        ]
        let updated = LedgerFacade.applySetupOpeningBalance(
            to: accounts,
            balancePaisa: 250_000,
            consentAutoUpdate: false,
            source: .typedManual
        )
        XCTAssertEqual(updated[0].balance, 250_000)
        XCTAssertFalse(updated[0].consentAutoUpdate)
        XCTAssertEqual(updated[1].balance, 7_200_000)
    }

    func testApplyConsentDeclinedClearsAutoUpdateOnly() {
        let accounts = [
            sampleHDFC(isDedicated: true, balance: 10_000_000, consent: true),
            sampleSBI(isDedicated: false, balance: 7_200_000)
        ]
        let updated = LedgerFacade.applyConsentDeclined(to: accounts)
        XCTAssertFalse(updated[0].consentAutoUpdate)
        XCTAssertEqual(updated[0].balance, 10_000_000)
        XCTAssertEqual(updated[1].balance, 7_200_000)
    }

    func testFacadeBalanceSourceMapsToLedgerEngine() {
        XCTAssertEqual(LedgerFacade.BalanceSource.snapshotFetch.engineSource, .fetched)
        XCTAssertEqual(LedgerFacade.BalanceSource.typedManual.engineSource, .typed)
        XCTAssertFalse(LedgerFacade.BalanceSource.snapshotFetch.engineSource.isTyped)
        XCTAssertTrue(LedgerFacade.BalanceSource.typedManual.engineSource.isTyped)
    }

    private func sampleHDFC(isDedicated: Bool, balance: Paisa, consent: Bool) -> Account {
        Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: balance,
            isDedicated: isDedicated,
            isPaytmLinked: true,
            consentAutoUpdate: consent
        )
    }

    private func sampleSBI(isDedicated: Bool, balance: Paisa) -> Account {
        Account(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            bankName: "SBI",
            maskedNumber: "••7730",
            balance: balance,
            isDedicated: isDedicated,
            isPaytmLinked: true,
            consentAutoUpdate: false
        )
    }
}
