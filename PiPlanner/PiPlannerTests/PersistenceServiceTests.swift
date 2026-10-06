import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class PersistenceServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PiPlannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testFreshInstallReturnsEmptyState() async throws {
        let state = try await persistence.loadState()

        XCTAssertTrue(state.accounts.isEmpty)
        XCTAssertTrue(state.goals.isEmpty)
        XCTAssertTrue(state.history.isEmpty)
        XCTAssertTrue(state.standingSplits.isEmpty)
    }

    func testSaveAndLoadRoundTrip() async throws {
        let account = Account(
            id: UUID(),
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: true
        )
        let goal = Goal(
            id: UUID(),
            name: "Emergency Fund",
            targetAmount: 20_000_000,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_731_000_000),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 5_000_000,
            shareOfNewCredits: Decimal(string: "0.4")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let split = StandingSplit(goalId: goal.id, percentage: Decimal(string: "1.0")!)
        let entry = HistoryEntry(
            id: UUID(),
            type: .openingBalance,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isLocked: true,
            previousBalance: nil,
            newBalance: 10_000_000,
            creditAmount: 10_000_000,
            isTyped: true,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: [
                GoalAllocation(
                    goalId: goal.id,
                    goalName: goal.name,
                    amount: 10_000_000,
                    percentage: Decimal(string: "1.0")!
                )
            ]
        )

        let saved = PersistedAppState(
            accounts: [account],
            goals: [goal],
            history: [entry],
            standingSplits: [split]
        )
        try await persistence.saveState(saved)

        let loaded = try await persistence.loadState()
        XCTAssertEqual(loaded.accounts, saved.accounts)
        XCTAssertEqual(loaded.goals.count, 1)
        XCTAssertEqual(loaded.goals[0].id, goal.id)
        XCTAssertEqual(loaded.history, saved.history)
        XCTAssertEqual(loaded.standingSplits, saved.standingSplits)
    }

    func testResetDemoClearsAllPersistedData() async throws {
        let seeded = PersistedAppState(
            accounts: [
                Account(
                    id: UUID(),
                    bankName: "HDFC",
                    maskedNumber: "••4821",
                    balance: 10_000_000,
                    isDedicated: true,
                    isPaytmLinked: true,
                    consentAutoUpdate: false
                )
            ],
            goals: [
                Goal(
                    id: UUID(),
                    name: "Car",
                    targetAmount: 50_000_000,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86_400 * 365),
                    inflationRate: Decimal(string: "0.07")!,
                    savedAmount: 1,
                    shareOfNewCredits: Decimal(string: "1.0")!,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            history: [
                HistoryEntry(
                    id: UUID(),
                    type: .newCredit,
                    createdAt: Date(),
                    isLocked: false,
                    previousBalance: 0,
                    newBalance: 100,
                    creditAmount: 100,
                    isTyped: true,
                    fromGoalId: nil,
                    toGoalId: nil,
                    transferAmount: nil,
                    withdrawalAmount: nil,
                    deletedGoalName: nil,
                    releasedAmount: nil,
                    allocations: []
                )
            ],
            standingSplits: [
                StandingSplit(goalId: UUID(), percentage: Decimal(string: "1.0")!)
            ]
        )
        try await persistence.saveState(seeded)

        try await persistence.resetDemo()

        let cleared = try await persistence.loadState()
        XCTAssertTrue(cleared.accounts.isEmpty)
        XCTAssertTrue(cleared.goals.isEmpty)
        XCTAssertTrue(cleared.history.isEmpty)
        XCTAssertTrue(cleared.standingSplits.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("app-state.json").path))
    }

    func testPostResetBehavesLikeFreshInstall() async throws {
        try await persistence.saveState(
            PersistedAppState(
                accounts: [
                    Account(
                        id: UUID(),
                        bankName: "SBI",
                        maskedNumber: "••7730",
                        balance: 1,
                        isDedicated: false,
                        isPaytmLinked: false,
                        consentAutoUpdate: false
                    )
                ],
                goals: [],
                history: [],
                standingSplits: []
            )
        )
        try await persistence.resetDemo()

        let afterReset = try await persistence.loadState()
        let fresh = PersistenceService(storageDirectory: temporaryDirectory.appendingPathComponent("other"))
        let freshState = try await fresh.loadState()

        XCTAssertEqual(afterReset, freshState)
    }
}
