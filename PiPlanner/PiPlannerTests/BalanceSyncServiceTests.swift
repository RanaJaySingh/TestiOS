import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class BalanceSyncServiceTests: XCTestCase {
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let unknownID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    func testFetchBalanceYesPathReturnsOneLakhRupees() async {
        let service = MockBalanceSyncService(knownAccountIDs: [hdfcID])
        let result = await service.fetchBalance(accountId: hdfcID)

        guard case .success(let paisa) = result else {
            return XCTFail("Expected success for known account")
        }
        XCTAssertEqual(paisa, 10_000_000)
        XCTAssertEqual(paisa, MockBalanceSyncService.demoBalancePaisa)
        XCTAssertEqual(FormattingService().formatINR(paisa: paisa), "₹1,00,000")
    }

    func testFetchBalanceUnknownAccountFails() async {
        let service = MockBalanceSyncService(knownAccountIDs: [hdfcID])
        let result = await service.fetchBalance(accountId: unknownID)
        XCTAssertEqual(result, .failure(.accountNotFound))
    }

    func testFetchBalanceEmptyKnownSetAlwaysSucceeds() async {
        let service = MockBalanceSyncService()
        let result = await service.fetchBalance(accountId: unknownID)
        XCTAssertEqual(result, .success(10_000_000))
    }

    func testVerifyUPIPinDemoSucceeds() async {
        let service = MockBalanceSyncService()
        let result = await service.verifyUPIPin(pin: MockBalanceSyncService.demoPIN)
        XCTAssertEqual(result, .success(10_000_000))
        XCTAssertEqual(MockBalanceSyncService.demoPIN, "1234")
    }

    func testVerifyUPIPinWrongPinFails() async {
        let service = MockBalanceSyncService()
        let result = await service.verifyUPIPin(pin: "0000")
        XCTAssertEqual(result, .failure(.wrongPin))
    }

    func testAccountOnOtherUPIAppForcesOtherAppError() {
        let service = MockBalanceSyncService()
        XCTAssertEqual(service.accountOnOtherUPIApp(), .otherApp)
    }

    func testManualContinueDisabledAtZero() {
        XCTAssertFalse(ConsentService.canContinueManual(amountPaisa: 0))
        XCTAssertTrue(ConsentService.canContinueManual(amountPaisa: 100))
        XCTAssertEqual(ConsentService.paisa(fromRupeeDigits: ""), 0)
        XCTAssertEqual(ConsentService.paisa(fromRupeeDigits: "0"), 0)
        XCTAssertEqual(ConsentService.paisa(fromRupeeDigits: "100000"), 10_000_000)
        XCTAssertEqual(ConsentService.paisa(fromRupeeDigits: "₹1,00,000"), 10_000_000)
    }

    func testPINCompleteness() {
        XCTAssertFalse(ConsentService.isCompletePIN(""))
        XCTAssertFalse(ConsentService.isCompletePIN("123"))
        XCTAssertFalse(ConsentService.isCompletePIN("12ab"))
        XCTAssertTrue(ConsentService.isCompletePIN("1234"))
    }

    func testConsentBulletsMatchPRDThemes() {
        let joined = ConsentService.consentBullets.joined(separator: " ").lowercased()
        XCTAssertEqual(ConsentService.consentBullets.count, 4)
        XCTAssertTrue(joined.contains("balance"))
        XCTAssertTrue(joined.contains("grok"))
        XCTAssertTrue(joined.contains("settings"))
    }
}
