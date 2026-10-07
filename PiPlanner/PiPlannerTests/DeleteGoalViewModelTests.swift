import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
import Combine

/// Xcode-host tests for DeleteGoalViewModel last-goal gate + engine confirm (PIP-106).
@MainActor
final class DeleteGoalViewModelTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testOnlyGoalGateBlocksConfirmUntilReplacement() async throws {
        let sole = sampleGoal(id: carID, name: "Car", saved: 6_000_000, share: 1)
        let persistence = DeleteVMInMemoryPersistence(
            initial: PersistedAppState(
                accounts: [],
                goals: [sole],
                history: [],
                standingSplits: [StandingSplit(goalId: carID, percentage: 1)],
                heldGoalChanges: []
            )
        )
        let viewModel = DeleteGoalViewModel(
            goal: sole,
            goals: [sole],
            persistence: persistence,
            clock: { self.createdAt },
            makeID: { UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")! }
        )

        XCTAssertEqual(viewModel.phase, .onlyGoalGate)
        XCTAssertFalse(viewModel.canConfirm)

        viewModel.replacementName = "Emergency Fund"
        viewModel.replacementTargetRupees = "100000"
        await viewModel.createReplacementGoal()

        XCTAssertEqual(viewModel.phase, .reassignDefault)
        XCTAssertTrue(viewModel.canConfirm)
        XCTAssertTrue(viewModel.standingResetToEqual)

        await viewModel.confirmDelete()
        XCTAssertTrue(viewModel.didDelete)

        let state = try await persistence.loadState()
        XCTAssertEqual(state.goals.count, 1)
        XCTAssertEqual(state.goals[0].name, "Emergency Fund")
        XCTAssertEqual(state.goals[0].savedAmount, 6_000_000)
        XCTAssertEqual(state.history.last?.type, .goalDeleted)
        XCTAssertEqual(state.history.last?.isLocked, true)
    }

    func testEqualDefaultThenConfirmWritesDeletedMovedHistory() async throws {
        let car = sampleGoal(id: carID, name: "Car", saved: 6_000_000, share: Decimal(string: "0.6")!)
        let emergency = sampleGoal(
            id: emergencyID,
            name: "Emergency Fund",
            saved: 4_000_000,
            share: Decimal(string: "0.4")!
        )
        let goals = [car, emergency]
        let persistence = DeleteVMInMemoryPersistence(
            initial: PersistedAppState(
                accounts: [],
                goals: goals,
                history: [],
                standingSplits: goals.map {
                    StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits)
                },
                heldGoalChanges: []
            )
        )
        let viewModel = DeleteGoalViewModel(
            goal: car,
            goals: goals,
            persistence: persistence,
            clock: { self.createdAt },
            makeID: { UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")! }
        )

        XCTAssertEqual(viewModel.phase, .reassignDefault)
        XCTAssertEqual(viewModel.displayPercents[emergencyID], 100)
        XCTAssertTrue(viewModel.canConfirm)

        await viewModel.confirmDelete()
        XCTAssertTrue(viewModel.didDelete)

        let state = try await persistence.loadState()
        XCTAssertEqual(state.goals.map(\.id), [emergencyID])
        XCTAssertEqual(state.goals[0].savedAmount, 10_000_000)
        XCTAssertEqual(state.history.last?.type, .goalDeleted)
        XCTAssertEqual(state.history.last?.releasedAmount, 6_000_000)
    }

    private func sampleGoal(id: UUID, name: String, saved: Paisa, share: Decimal) -> Goal {
        Goal(
            id: id,
            name: name,
            targetAmount: 50_000_000,
            startDate: createdAt,
            endDate: createdAt.addingTimeInterval(86_400 * 365),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: saved,
            shareOfNewCredits: share,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

private final class DeleteVMInMemoryPersistence: PersistenceServicing, @unchecked Sendable {
    private var state: PersistedAppState
    init(initial: PersistedAppState) { state = initial }
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
#endif
