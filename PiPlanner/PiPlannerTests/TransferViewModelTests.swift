import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
import Combine

/// Xcode-host tests for TransferViewModel Complete → no second Move (PIP-55 round-1 must-fix).
@MainActor
final class TransferViewModelTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testConfirmMoveTwiceDoesNotWriteSecondHistoryEntry() async throws {
        let persistence = TransferVMInMemoryPersistence(initial: sampleState())
        let viewModel = TransferViewModel(
            goals: sampleState().goals,
            standingSplits: sampleState().standingSplits,
            persistence: persistence,
            clock: { self.createdAt },
            makeID: { UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")! }
        )
        viewModel.selectFrom(carID)
        viewModel.selectTo(emergencyID)
        viewModel.applyChip(rupees: 5_000)

        XCTAssertTrue(viewModel.canMove)
        await viewModel.confirmMove()
        XCTAssertTrue(viewModel.didComplete)
        XCTAssertFalse(viewModel.canMove, "Move must stay disabled after Complete")

        let historyAfterFirst = try await persistence.loadState().history
        XCTAssertEqual(historyAfterFirst.filter { $0.type == .transfer }.count, 1)

        // Second tap must no-op (defense in depth).
        await viewModel.confirmMove()
        let stateAfterSecond = try await persistence.loadState()
        XCTAssertEqual(
            stateAfterSecond.history.filter { $0.type == .transfer }.count,
            1,
            "Second confirmMove must not append another Transfer History entry"
        )
        let car = try XCTUnwrap(stateAfterSecond.goals.first { $0.id == carID })
        XCTAssertEqual(car.savedAmount, 5_500_000)
    }

    private func sampleState() -> PersistedAppState {
        let goals = [
            Goal(
                id: carID,
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
                id: emergencyID,
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
        return PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: goals.map {
                StandingSplit(goalId: $0.id, percentage: $0.shareOfNewCredits)
            },
            heldGoalChanges: []
        )
    }
}

private final class TransferVMInMemoryPersistence: PersistenceServicing, @unchecked Sendable {
    private var state: PersistedAppState
    init(initial: PersistedAppState) { state = initial }
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
#endif
