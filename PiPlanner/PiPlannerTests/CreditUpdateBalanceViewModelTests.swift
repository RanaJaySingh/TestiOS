import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

@MainActor
final class CreditUpdateBalanceViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let goalA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let goalB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CreditUpdateVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
        try await persistence.saveState(samplePostSetupState(isPaytmLinked: true))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testChooseBalanceSyncPaytmGoesToPin() async {
        let viewModel = CreditUpdateBalanceViewModel(persistence: persistence)
        await viewModel.loadAndPrepare()
        viewModel.chooseBalanceSync()
        XCTAssertEqual(viewModel.path, .pin)
    }

    func testChooseBalanceSyncOtherUPIGoesToOtherAppThenManual() async throws {
        try await persistence.saveState(samplePostSetupState(isPaytmLinked: false))
        let viewModel = CreditUpdateBalanceViewModel(persistence: persistence)
        await viewModel.loadAndPrepare()
        viewModel.chooseBalanceSync()
        XCTAssertEqual(viewModel.path, .otherApp)
        viewModel.continueFromOtherApp()
        XCTAssertEqual(viewModel.path, .manual)
    }

    func testManualAndPINCreateSameHistoryShape() async {
        let sync = MockBalanceSyncService(fetchedBalancePaisa: 11_000_000)
        let manualVM = CreditUpdateBalanceViewModel(persistence: persistence, balanceSync: sync)
        await manualVM.loadAndPrepare()
        manualVM.chooseManual()
        manualVM.rupeeDigits = "110000"
        await manualVM.applyTypedBalance()
        let manualEntry = manualVM.createdEntry
        XCTAssertNotNil(manualEntry)
        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(manualEntry!))
        XCTAssertEqual(manualEntry?.isTyped, true)

        // Reset state for PIN path (open credit blocks second update).
        try? await persistence.saveState(samplePostSetupState(isPaytmLinked: true))
        let pinVM = CreditUpdateBalanceViewModel(persistence: persistence, balanceSync: sync)
        await pinVM.loadAndPrepare()
        pinVM.chooseBalanceSync()
        pinVM.appendPINDigit("1")
        pinVM.appendPINDigit("2")
        pinVM.appendPINDigit("3")
        pinVM.appendPINDigit("4")
        await pinVM.submitPIN()
        let pinEntry = pinVM.createdEntry
        XCTAssertNotNil(pinEntry)
        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(pinEntry!))
        XCTAssertEqual(pinEntry?.isTyped, false)
        XCTAssertEqual(manualEntry?.creditAmount, pinEntry?.creditAmount)
        XCTAssertEqual(manualEntry?.type, pinEntry?.type)
    }

    func testWrongPinRoutesToWrongPinThenManual() async {
        let viewModel = CreditUpdateBalanceViewModel(persistence: persistence)
        await viewModel.loadAndPrepare()
        viewModel.chooseBalanceSync()
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        viewModel.appendPINDigit("0")
        await viewModel.submitPIN()
        XCTAssertEqual(viewModel.path, .wrongPin)
        viewModel.enterManuallyAfterWrongPin()
        XCTAssertEqual(viewModel.path, .manual)
    }

    private func samplePostSetupState(isPaytmLinked: Bool) -> PersistedAppState {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let goals = [
            Goal(
                id: goalA,
                name: "Emergency",
                targetAmount: 5_000_000,
                startDate: now,
                endDate: now.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.60")!,
                createdAt: now,
                updatedAt: now
            ),
            Goal(
                id: goalB,
                name: "Vacation",
                targetAmount: 3_000_000,
                startDate: now,
                endDate: now.addingTimeInterval(86_400 * 180),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.40")!,
                createdAt: now,
                updatedAt: now
            )
        ]
        let hdfc = Account(
            id: hdfcID,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: isPaytmLinked,
            consentAutoUpdate: false
        )
        let opening = try! OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                goalA: Decimal(string: "0.60")!,
                goalB: Decimal(string: "0.40")!
            ],
            isTyped: false
        )
        return PersistedAppState(
            accounts: [hdfc],
            goals: goals,
            history: [opening],
            standingSplits: [
                StandingSplit(goalId: goalA, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: goalB, percentage: Decimal(string: "0.40")!)
            ]
        )
    }
}
