import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

@MainActor
final class ConsentViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConsentVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testConsentYesFetchesDemoBalance() async {
        let viewModel = makeViewModel()
        let paisa = await viewModel.chooseConsentYes()
        XCTAssertEqual(paisa, 10_000_000)
        XCTAssertEqual(viewModel.resolvedBalance, 10_000_000)
        XCTAssertTrue(viewModel.consentAutoUpdate)
        XCTAssertEqual(viewModel.formattedResolvedBalance, "₹1,00,000")
    }

    func testConsentNoClearsResolvedBalance() {
        let viewModel = makeViewModel()
        viewModel.chooseConsentNo()
        XCTAssertFalse(viewModel.consentAutoUpdate)
        XCTAssertNil(viewModel.resolvedBalance)
    }

    func testManualZeroDisablesContinue() async {
        let viewModel = makeViewModel()
        viewModel.setManualRupeeDigits("0")
        XCTAssertFalse(viewModel.canContinueManual)
        XCTAssertNil(await viewModel.continueManual())

        viewModel.setManualRupeeDigits("2500")
        XCTAssertTrue(viewModel.canContinueManual)
        let paisa = await viewModel.continueManual()
        XCTAssertEqual(paisa, 250_000)
    }

    func testPINSuccessAndFailure() async {
        let viewModel = makeViewModel()
        viewModel.appendPINDigit("1")
        viewModel.appendPINDigit("2")
        viewModel.appendPINDigit("3")
        viewModel.appendPINDigit("4")
        let success = await viewModel.checkBalanceWithPIN()
        XCTAssertEqual(success, .success(10_000_000))

        viewModel.clearPIN()
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        let failure = await viewModel.checkBalanceWithPIN()
        XCTAssertEqual(failure, .wrongPin)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testOtherAppForcesManualPathSignal() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.accountOnOtherUPIApp(), .otherApp)
        XCTAssertEqual(viewModel.lastPinOutcome, .otherApp)
        XCTAssertEqual(viewModel.pinDigits, "")
    }

    private func makeViewModel() -> ConsentViewModel {
        let accounts = [
            Account(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                bankName: "HDFC",
                maskedNumber: "••4821",
                balance: 10_000_000,
                isDedicated: true,
                isPaytmLinked: true,
                consentAutoUpdate: false
            ),
            Account(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                bankName: "SBI",
                maskedNumber: "••7730",
                balance: 7_200_000,
                isDedicated: false,
                isPaytmLinked: true,
                consentAutoUpdate: false
            )
        ]
        return ConsentViewModel(accounts: accounts, persistence: persistence)
    }
}
