import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
#endif

#if canImport(Combine)
import Combine

/// Xcode-host ViewModel tests (excluded from Linux `swift test`).
@MainActor
final class WithdrawalViewModelTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testFinishEditRefusesInvalidTotalAndAllowsAnotherEditPass() {
        let goals = sampleGoals()
        let shortfall: Paisa = 1_500_000
        let viewModel = WithdrawalViewModel(
            shortfall: shortfall,
            previousBalance: 10_000_000,
            newBalance: 8_500_000,
            goals: goals,
            persistence: InMemoryPersistence()
        )

        viewModel.beginEdit()
        XCTAssertEqual(viewModel.phase, .edit)
        XCTAssertFalse(viewModel.hasEditedOnce)

        // Make total reductions ≠ shortfall (under by ₹1,000).
        viewModel.setEditRupeeDigits(goalID: carID, digits: "8000")
        viewModel.setEditRupeeDigits(goalID: emergencyID, digits: "4500")
        // Vacation left at proportional 1500 → total 14,000 ≠ 15,000
        viewModel.finishEdit()

        XCTAssertFalse(viewModel.hasEditedOnce)
        XCTAssertEqual(viewModel.phase, .invalidTotal)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.canStartEdit) // refused Done must not soft-lock

        // Another edit pass — fix to exact shortfall (₹15,000): 9000 + 4500 + 1500
        viewModel.beginEdit()
        viewModel.setEditRupeeDigits(goalID: carID, digits: "9000")
        viewModel.setEditRupeeDigits(goalID: emergencyID, digits: "4500")
        viewModel.setEditRupeeDigits(goalID: goals[2].id, digits: "1500")
        viewModel.finishEdit()

        XCTAssertTrue(viewModel.hasEditedOnce)
        XCTAssertEqual(viewModel.phase, .proportionalDefault)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.canSave)
        XCTAssertFalse(viewModel.canStartEdit)
    }

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 10_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.60")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 5_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 3_000_000,
                shareOfNewCredits: Decimal(string: "0.30")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                name: "Vacation",
                targetAmount: 2_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 1_000_000,
                shareOfNewCredits: Decimal(string: "0.10")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}

private final class InMemoryPersistence: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState(
        accounts: [],
        goals: [],
        history: [],
        standingSplits: [],
        heldGoalChanges: []
    )

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws {
        state = PersistedAppState(
            accounts: [],
            goals: [],
            history: [],
            standingSplits: [],
            heldGoalChanges: []
        )
    }
}
#endif
