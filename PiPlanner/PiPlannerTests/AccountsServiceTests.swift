import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class AccountsServiceTests: XCTestCase {
    func testTogglingOneDedicatedTurnsOtherOff() {
        let hdfc = sampleHDFC(isDedicated: false)
        let sbi = sampleSBI(isDedicated: false)

        let afterHDFC = AccountsService.applyingDedicatedToggle(
            accountID: hdfc.id,
            isDedicated: true,
            to: [hdfc, sbi]
        )
        XCTAssertTrue(afterHDFC[0].isDedicated)
        XCTAssertFalse(afterHDFC[1].isDedicated)
        XCTAssertTrue(AccountsService.hasExactlyOneDedicated(afterHDFC))

        let afterSBI = AccountsService.applyingDedicatedToggle(
            accountID: sbi.id,
            isDedicated: true,
            to: afterHDFC
        )
        XCTAssertFalse(afterSBI[0].isDedicated)
        XCTAssertTrue(afterSBI[1].isDedicated)
        XCTAssertEqual(AccountsService.dedicatedCount(afterSBI), 1)
        XCTAssertEqual(AccountsService.dedicatedAccount(in: afterSBI)?.id, sbi.id)
    }

    func testTurningDedicatedOffLeavesNone() {
        let hdfc = sampleHDFC(isDedicated: true)
        let sbi = sampleSBI(isDedicated: false)

        let updated = AccountsService.applyingDedicatedToggle(
            accountID: hdfc.id,
            isDedicated: false,
            to: [hdfc, sbi]
        )
        XCTAssertFalse(updated[0].isDedicated)
        XCTAssertFalse(updated[1].isDedicated)
        XCTAssertEqual(AccountsService.dedicatedCount(updated), 0)
        XCTAssertFalse(AccountsService.canContinue(with: updated))
    }

    func testContinueGatingRequiresExactlyOneDedicated() {
        let none = [sampleHDFC(isDedicated: false), sampleSBI(isDedicated: false)]
        XCTAssertFalse(AccountsService.canContinue(with: none))
        XCTAssertTrue(
            AccountsService.statusMessage(for: none)
                .localizedCaseInsensitiveContains("exactly one")
        )

        let one = [sampleHDFC(isDedicated: true), sampleSBI(isDedicated: false)]
        XCTAssertTrue(AccountsService.canContinue(with: one))
        XCTAssertTrue(AccountsService.statusMessage(for: one).contains("HDFC"))

        // Defensive multi-dedicated state (should not occur via toggle).
        let both = [sampleHDFC(isDedicated: true), sampleSBI(isDedicated: true)]
        XCTAssertFalse(AccountsService.canContinue(with: both))
    }

    func testDisplayTitleMatchesTicketCopy() {
        let hdfc = sampleHDFC(isDedicated: false)
        let sbi = sampleSBI(isDedicated: false)
        XCTAssertEqual(AccountsService.displayTitle(for: hdfc), "HDFC ••4821")
        XCTAssertEqual(AccountsService.displayTitle(for: sbi), "SBI ••7730")
    }

    private func sampleHDFC(isDedicated: Bool) -> Account {
        Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: isDedicated,
            isPaytmLinked: true,
            consentAutoUpdate: false
        )
    }

    private func sampleSBI(isDedicated: Bool) -> Account {
        Account(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            bankName: "SBI",
            maskedNumber: "••7730",
            balance: 7_200_000,
            isDedicated: isDedicated,
            isPaytmLinked: true,
            consentAutoUpdate: false
        )
    }
}
