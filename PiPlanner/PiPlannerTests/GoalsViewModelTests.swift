import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
#endif

#if canImport(Combine)
import Combine

/// Xcode-host ViewModel tests (excluded from Linux `swift test` — needs Combine / @MainActor app target).
@MainActor
final class GoalsViewModelTests: XCTestCase {
    func testLoadExposesGoalsAndFormattedTotal() async throws {
        let persistence = InMemoryPersistence()
        let state = makePostSetupState(consent: true)
        try await persistence.saveState(state)

        let viewModel = GoalsViewModel(persistence: persistence)
        await viewModel.load()

        XCTAssertEqual(viewModel.goals.count, 2)
        XCTAssertEqual(viewModel.formattedTotalSavings, "₹1,00,000")
        XCTAssertEqual(viewModel.balanceAction, .sync)
        XCTAssertEqual(viewModel.balanceActionTitle, "Sync")
        XCTAssertTrue(viewModel.hasGoals)
    }

    func testConsentOffShowsUpdateBalanceAndOpensSheet() async throws {
        let persistence = InMemoryPersistence()
        try await persistence.saveState(makePostSetupState(consent: false))
        let viewModel = GoalsViewModel(persistence: persistence)
        await viewModel.load()

        XCTAssertEqual(viewModel.balanceAction, .updateBalance)
        viewModel.tapBalanceAction()
        XCTAssertTrue(viewModel.showUpdateBalanceSheet)
        XCTAssertFalse(viewModel.showSyncSheet)
    }

    func testConsentOnOpensSyncSheet() async throws {
        let persistence = InMemoryPersistence()
        try await persistence.saveState(makePostSetupState(consent: true))
        let viewModel = GoalsViewModel(persistence: persistence)
        await viewModel.load()

        viewModel.tapBalanceAction()
        XCTAssertTrue(viewModel.showSyncSheet)
        XCTAssertFalse(viewModel.showUpdateBalanceSheet)
    }

    func testSelectGoalAndOpenSettings() async throws {
        let persistence = InMemoryPersistence()
        let state = makePostSetupState(consent: true)
        try await persistence.saveState(state)
        let viewModel = GoalsViewModel(persistence: persistence)
        await viewModel.load()

        let goal = try XCTUnwrap(viewModel.goals.first)
        viewModel.selectGoal(goal)
        XCTAssertEqual(viewModel.selectedGoalID, goal.id)
        XCTAssertEqual(viewModel.selectedGoal?.name, goal.name)

        viewModel.openSettings()
        XCTAssertTrue(viewModel.showSettings)
    }

    func testPerformSyncUpdatesDedicatedBalance() async throws {
        let persistence = InMemoryPersistence()
        var state = makePostSetupState(consent: true)
        state.accounts[0].balance = 5_000_000
        try await persistence.saveState(state)

        let sync = MockBalanceSyncService(knownAccountIDs: [state.accounts[0].id])
        let viewModel = GoalsViewModel(persistence: persistence, balanceSync: sync)
        await viewModel.load()
        viewModel.showSyncSheet = true
        await viewModel.performSync()

        XCTAssertFalse(viewModel.showSyncSheet)
        XCTAssertEqual(viewModel.totalSavingsPaisa, MockBalanceSyncService.demoBalancePaisa)
    }

    // MARK: - Fixtures

    private func makePostSetupState(consent: Bool) -> PersistedAppState {
        let account = Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: consent
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400 * 365)
        let car = Goal(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Car",
            targetAmount: 50_000_000,
            startDate: start,
            endDate: end,
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 6_000_000,
            shareOfNewCredits: Decimal(string: "0.6")!,
            createdAt: start,
            updatedAt: start
        )
        let emergency = Goal(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            name: "Emergency Fund",
            targetAmount: 20_000_000,
            startDate: start,
            endDate: end,
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 4_000_000,
            shareOfNewCredits: Decimal(string: "0.4")!,
            createdAt: start,
            updatedAt: start
        )
        let opening = HistoryEntry(
            id: UUID(),
            type: .openingBalance,
            createdAt: start,
            isLocked: true,
            previousBalance: nil,
            newBalance: 10_000_000,
            creditAmount: 10_000_000,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
        return PersistedAppState(
            accounts: [account],
            goals: [car, emergency],
            history: [opening],
            standingSplits: []
        )
    }
}

private final class InMemoryPersistence: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
#endif
