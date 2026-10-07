import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class TransferServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Chips / parsing

    func testChipsConvertToPaisa() {
        XCTAssertEqual(TransferService.chipRupees, [1_000, 5_000, 10_000])
        XCTAssertEqual(TransferService.chipAmountPaisa(at: 0), 100_000)
        XCTAssertEqual(TransferService.chipAmountPaisa(at: 1), 500_000)
        XCTAssertEqual(TransferService.chipAmountPaisa(at: 2), 1_000_000)
        XCTAssertNil(TransferService.chipAmountPaisa(at: 3))
    }

    func testParseAmountPaisaFromRupeesText() {
        XCTAssertEqual(TransferService.parseAmountPaisa(fromRupeesText: "5000"), 500_000)
        XCTAssertEqual(TransferService.parseAmountPaisa(fromRupeesText: "₹5,000"), 500_000)
        XCTAssertEqual(TransferService.parseAmountPaisa(fromRupeesText: ""), 0)
    }

    // MARK: - Validation / phases

    func testOverAmountDisablesMove() {
        let goals = sampleGoals()
        let amount: Paisa = 7_000_000 // Car has 6_000_000
        XCTAssertTrue(
            TransferService.isOverAmount(amountPaisa: amount, fromSaved: 6_000_000)
        )
        XCTAssertFalse(
            TransferService.canMove(
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: amount,
                goals: goals
            )
        )
        XCTAssertEqual(
            TransferService.resolvePhase(
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: amount,
                goals: goals,
                isComplete: false
            ),
            .overAmount
        )
    }

    func testValidAmountEntersPreviewPhase() {
        let goals = sampleGoals()
        let amount: Paisa = 500_000
        XCTAssertEqual(
            TransferService.resolvePhase(
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: amount,
                goals: goals,
                isComplete: false
            ),
            .preview
        )
        XCTAssertTrue(
            TransferService.canMove(
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: amount,
                goals: goals
            )
        )
        let preview = TransferService.preview(
            fromGoalId: carID,
            toGoalId: emergencyID,
            amountPaisa: amount,
            goals: goals
        )
        XCTAssertEqual(preview?.fromAfter, 5_500_000)
        XCTAssertEqual(preview?.toAfter, 4_500_000)
    }

    func testSelectPhaseWhenGoalsMissing() {
        XCTAssertEqual(
            TransferService.resolvePhase(
                fromGoalId: nil,
                toGoalId: emergencyID,
                amountPaisa: 100_000,
                goals: sampleGoals(),
                isComplete: false
            ),
            .select
        )
    }

    func testEnterAmountPhaseWhenZero() {
        XCTAssertEqual(
            TransferService.resolvePhase(
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: 0,
                goals: sampleGoals(),
                isComplete: false
            ),
            .enterAmount
        )
    }

    // MARK: - Apply: money + History + standing unchanged (BR-7)

    func testApplyTransferMovesMoneyAndWritesHistory() throws {
        let state = sampleState()
        let entryID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let amount: Paisa = 500_000

        let next = try TransferService.applyTransfer(
            to: state,
            fromGoalId: carID,
            toGoalId: emergencyID,
            amountPaisa: amount,
            entryID: entryID,
            now: createdAt
        )

        let car = try XCTUnwrap(next.goals.first { $0.id == carID })
        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        XCTAssertEqual(car.savedAmount, 5_500_000)
        XCTAssertEqual(emergency.savedAmount, 4_500_000)

        let entry = try XCTUnwrap(next.history.last)
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .transfer)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.fromGoalId, carID)
        XCTAssertEqual(entry.toGoalId, emergencyID)
        XCTAssertEqual(entry.transferAmount, amount)
        XCTAssertEqual(entry.allocations.count, 2)

        let title = TransferService.historyTitle(
            fromName: "Car",
            toName: "Emergency Fund",
            amountPaisa: amount
        )
        XCTAssertEqual(title, "Car → Emergency Fund · ₹5,000")
        XCTAssertEqual(TransferService.historyTypeLabel, "Transfer")
    }

    func testApplyTransferLeavesStandingSplitUnchanged() throws {
        let state = sampleState()
        let standingBefore = state.standingSplits
        let sharesBefore = Dictionary(uniqueKeysWithValues: state.goals.map {
            ($0.id, $0.shareOfNewCredits)
        })

        let next = try TransferService.applyTransfer(
            to: state,
            fromGoalId: carID,
            toGoalId: emergencyID,
            amountPaisa: 100_000,
            now: createdAt
        )

        XCTAssertEqual(next.standingSplits, standingBefore)
        for goal in next.goals {
            XCTAssertEqual(goal.shareOfNewCredits, sharesBefore[goal.id])
        }
    }

    func testApplyTransferRejectsOverAmount() {
        XCTAssertThrowsError(
            try TransferService.applyTransfer(
                to: sampleState(),
                fromGoalId: carID,
                toGoalId: emergencyID,
                amountPaisa: 9_000_000
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error")
            }
            XCTAssertEqual(validation.code, .amountExceedsSaved)
        }
    }

    func testCreateLockedEntryRejectsSameGoal() {
        let goals = sampleGoals()
        let car = goals[0]
        XCTAssertThrowsError(
            try TransferService.createLockedTransferEntry(
                from: car,
                to: car,
                amountPaisa: 100_000
            )
        )
    }

    // MARK: - Prefill (16c)

    func testAskTransferProposalMapsToPrefill() {
        let action = ProposedAction.transfer(
            from: carID,
            to: emergencyID,
            amount: 500_000
        )
        let prefill = StubGrokService.transferPrefill(from: action)
        XCTAssertEqual(prefill?.fromGoalId, carID)
        XCTAssertEqual(prefill?.toGoalId, emergencyID)
        XCTAssertEqual(prefill?.amountPaisa, 500_000)
    }

    func testStubAskQuestionReturnsTransferProposal() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "Transfer money from car")
        guard case .success(.actionProposal(let action)) = result else {
            return XCTFail("Expected transfer proposal, got \(result)")
        }
        guard case .transfer(let from, let to, let amount) = action else {
            return XCTFail("Expected transfer action")
        }
        XCTAssertEqual(from, carID)
        XCTAssertEqual(to, emergencyID)
        XCTAssertEqual(amount, 500_000)
    }

    // MARK: - Fixtures

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.50")!,
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
                shareOfNewCredits: Decimal(string: "0.30")!,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            Goal(
                id: vacationID,
                name: "Vacation",
                targetAmount: 10_000_000,
                startDate: createdAt,
                endDate: createdAt.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 1_000_000,
                shareOfNewCredits: Decimal(string: "0.20")!,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }

    private func sampleState() -> PersistedAppState {
        let goals = sampleGoals()
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
