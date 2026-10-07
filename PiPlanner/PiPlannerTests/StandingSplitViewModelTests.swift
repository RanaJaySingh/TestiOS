import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
#endif

#if canImport(Combine)
import Combine

/// Xcode-host ViewModel tests (excluded from Linux `swift test`).
@MainActor
final class StandingSplitViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var persistence: PersistenceService!

    override func setUp() async throws {
        try await super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StandingSplitVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(storageDirectory: temporaryDirectory)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        persistence = nil
        temporaryDirectory = nil
        try await super.tearDown()
    }

    func testSaveDisabledUntilPercentsSumTo100() {
        let goals = sampleGoals()
        let viewModel = StandingSplitViewModel(
            goals: goals,
            persistence: persistence,
            initialPercents: [
                goals[0].id: 60,
                goals[1].id: 20
            ]
        )

        XCTAssertFalse(viewModel.canSave)
        XCTAssertFalse(viewModel.isValidTotal)
        XCTAssertTrue(viewModel.statusMessage.contains("Assign the remaining"))

        viewModel.setDisplayPercent(goalID: goals[1].id, percent: 40)
        XCTAssertTrue(viewModel.canSave)
        XCTAssertTrue(viewModel.isValidTotal)
    }

    func testSingleGoalSkipsEditorAndAutosavesHundred() async throws {
        let goal = sampleGoals()[0]
        try await persistence.saveState(
            PersistedAppState(accounts: [], goals: [goal], history: [], standingSplits: [])
        )
        let viewModel = StandingSplitViewModel(
            goals: [goal],
            persistence: persistence
        )

        XCTAssertFalse(viewModel.shouldPresentEditor)
        XCTAssertTrue(viewModel.isSingleGoal)

        await viewModel.applySingleGoalSkipIfNeeded()

        XCTAssertTrue(viewModel.didAutoSkip)
        XCTAssertTrue(viewModel.didSave)
        let state = try await persistence.loadState()
        XCTAssertEqual(state.standingSplits.first?.percentage, Decimal(1))
        XCTAssertEqual(state.goals.first?.savedAmount, goal.savedAmount)
    }

    func testSavePersistsStandingSplitForNextCredit() async throws {
        let goals = sampleGoals()
        try await persistence.saveState(
            PersistedAppState(
                accounts: [],
                goals: goals,
                history: [],
                standingSplits: [
                    StandingSplit(goalId: goals[0].id, percentage: Decimal(string: "0.6")!),
                    StandingSplit(goalId: goals[1].id, percentage: Decimal(string: "0.4")!)
                ]
            )
        )

        let viewModel = StandingSplitViewModel(
            goals: goals,
            persistence: persistence,
            initialPercents: [
                goals[0].id: 55,
                goals[1].id: 45
            ]
        )
        await viewModel.save()

        XCTAssertTrue(viewModel.didSave)
        XCTAssertTrue(viewModel.shouldDismiss)
        XCTAssertEqual(
            viewModel.statusMessage,
            StandingSplitService.changeAppliesNextCreditMessage
        )

        let state = try await persistence.loadState()
        let next = StandingSplitService.percentagesForNextCredit(from: state)
        XCTAssertEqual(next[goals[0].id], Decimal(string: "0.55")!)
        XCTAssertEqual(next[goals[1].id], Decimal(string: "0.45")!)
        XCTAssertEqual(state.goals.map(\.savedAmount).reduce(0, +), 10_000_000)
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
                savedAmount: 6_000_000,
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
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}
#endif
