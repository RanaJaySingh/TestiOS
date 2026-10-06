import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

@MainActor
final class AccountsViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccountsVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testToggleExclusivityAndContinueGating() {
        let accounts = sampleAccounts()
        let viewModel = AccountsViewModel(accounts: accounts, persistence: persistence)

        XCTAssertFalse(viewModel.canContinue)

        viewModel.setDedicated(accountID: accounts[0].id, isDedicated: true)
        XCTAssertTrue(viewModel.accounts[0].isDedicated)
        XCTAssertFalse(viewModel.accounts[1].isDedicated)
        XCTAssertTrue(viewModel.canContinue)

        viewModel.setDedicated(accountID: accounts[1].id, isDedicated: true)
        XCTAssertFalse(viewModel.accounts[0].isDedicated)
        XCTAssertTrue(viewModel.accounts[1].isDedicated)
        XCTAssertTrue(viewModel.canContinue)

        viewModel.setDedicated(accountID: accounts[1].id, isDedicated: false)
        XCTAssertFalse(viewModel.canContinue)
    }

    func testContinuePersistsAndNavigatesToConsent() async throws {
        let accounts = sampleAccounts()
        let viewModel = AccountsViewModel(accounts: accounts, persistence: persistence)

        // None dedicated → Continue is a no-op.
        await viewModel.continueToConsent()
        XCTAssertFalse(viewModel.shouldNavigateToConsent)

        viewModel.setDedicated(accountID: accounts[0].id, isDedicated: true)
        await viewModel.continueToConsent()

        XCTAssertTrue(viewModel.shouldNavigateToConsent)
        let state = try await persistence.loadState()
        XCTAssertEqual(state.accounts.count, 2)
        XCTAssertEqual(AccountsService.dedicatedCount(state.accounts), 1)
        XCTAssertEqual(
            AccountsService.dedicatedAccount(in: state.accounts)?.bankName,
            "HDFC"
        )
    }

    private func sampleAccounts() -> [Account] {
        [
            Account(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                bankName: "HDFC",
                maskedNumber: "••4821",
                balance: 10_000_000,
                isDedicated: false,
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
    }
}
