import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

@MainActor
final class OpeningSplitViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpeningSplitVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testMultiGoalLockDisabledUntilPercentsSumTo100() {
        let goals = sampleGoals()
        let viewModel = OpeningSplitViewModel(
            goals: goals,
            openingBalance: 10_000_000,
            persistence: persistence,
            initialPercents: [
                goals[0].id: 60,
                goals[1].id: 20
            ]
        )

        XCTAssertFalse(viewModel.canLock)
        XCTAssertTrue(viewModel.statusMessage.contains("Assign the remaining"))

        viewModel.setDisplayPercent(goalID: goals[1].id, percent: 40)
        XCTAssertTrue(viewModel.canLock)
    }

    func testSingleGoalAutoAssigns100WithoutEditableNeed() {
        let goal = sampleGoals()[0]
        let viewModel = OpeningSplitViewModel(
            goals: [goal],
            openingBalance: 10_000_000,
            persistence: persistence
        )

        XCTAssertTrue(viewModel.isSingleGoal)
        XCTAssertEqual(viewModel.displayPercents[goal.id], 100)
        XCTAssertTrue(viewModel.canLock)
        // Frame 8b: changing % is a no-op for single goal.
        viewModel.setDisplayPercent(goalID: goal.id, percent: 50)
        XCTAssertEqual(viewModel.displayPercents[goal.id], 100)
    }

    func testConfirmLockCreatesOpeningHistoryEntryAndNavigates() async throws {
        let goals = sampleGoals()
        try await persistence.saveState(
            PersistedAppState(accounts: [], goals: goals, history: [], standingSplits: [])
        )

        let fixedID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let viewModel = OpeningSplitViewModel(
            goals: goals,
            openingBalance: 10_000_000,
            persistence: persistence,
            initialPercents: [
                goals[0].id: 60,
                goals[1].id: 40
            ],
            clock: { fixedDate },
            makeID: { fixedID }
        )

        await viewModel.confirmLock()

        XCTAssertTrue(viewModel.shouldNavigateToGoals)
        XCTAssertTrue(viewModel.isReadOnly)
        XCTAssertEqual(viewModel.lockedEntry?.id, fixedID)
        XCTAssertEqual(viewModel.lockedEntry?.type, .openingBalance)
        XCTAssertEqual(viewModel.statusMessage, OpeningSplitService.lockedAmountsCaption)

        let state = try await persistence.loadState()
        XCTAssertEqual(state.history.count, 1)
        XCTAssertTrue(state.history[0].isLocked)
        XCTAssertEqual(state.history[0].type, .openingBalance)
        XCTAssertEqual(state.goals.map(\.savedAmount).reduce(0, +), 10_000_000)
    }

    func testReadOnlyFactoryExposesLockedCaption() throws {
        let goals = sampleGoals()
        let entry = try OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                goals[0].id: Decimal(string: "0.60")!,
                goals[1].id: Decimal(string: "0.40")!
            ]
        )
        let viewModel = OpeningSplitViewModel.readOnly(
            entry: entry,
            goals: goals,
            persistence: persistence
        )

        XCTAssertTrue(viewModel.isReadOnly)
        XCTAssertFalse(viewModel.canLock)
        XCTAssertEqual(viewModel.statusMessage, "Locked amounts never change")
        viewModel.setDisplayPercent(goalID: goals[0].id, percent: 10)
        XCTAssertEqual(viewModel.displayPercents[goals[0].id], 60)
    }

    private func sampleGoals() -> [Goal] {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            Goal(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}
