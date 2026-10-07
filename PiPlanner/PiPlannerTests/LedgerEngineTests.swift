import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// PIP-102 — StubLedgerEngine: pending edits → open History with suggested split; BR-6 block.
final class LedgerEngineTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_100)
    private let ledger: any LedgerEngine = StubLedgerEngine()

    // MARK: - Apply pending before open entry

    func testHigherBalanceAppliesPendingEditsThenWritesOpenEntryWithSuggestedSplit() throws {
        var state = samplePostSetupState()
        // Simulate pending share change that is NOT yet on the live goals (v3 / safety path).
        state.goals = state.goals.map { goal in
            guard goal.id == carID else { return goal }
            var stale = goal
            stale.shareOfNewCredits = Decimal(string: "0.60")!
            return stale
        }
        state.standingSplits = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
        ]
        state.heldGoalChanges = [
            HeldGoalChange(
                id: UUID(),
                goalId: carID,
                savedAt: createdAt.addingTimeInterval(-60),
                previousName: "Car",
                pendingName: "Car",
                previousTargetAmount: 50_000_000,
                pendingTargetAmount: 50_000_000,
                previousShareOfNewCredits: Decimal(string: "0.60")!,
                pendingShareOfNewCredits: Decimal(string: "0.70")!,
                previousInflationRate: Decimal(string: "0.07")!,
                pendingInflationRate: Decimal(string: "0.07")!,
                previousStartDate: Date(timeIntervalSince1970: 1_700_000_000),
                pendingStartDate: Date(timeIntervalSince1970: 1_700_000_000),
                previousEndDate: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(86_400 * 365),
                pendingEndDate: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(86_400 * 365)
            ),
            HeldGoalChange(
                id: UUID(),
                goalId: emergencyID,
                savedAt: createdAt.addingTimeInterval(-60),
                previousName: "Emergency Fund",
                pendingName: "Emergency Fund",
                previousTargetAmount: 20_000_000,
                pendingTargetAmount: 20_000_000,
                previousShareOfNewCredits: Decimal(string: "0.40")!,
                pendingShareOfNewCredits: Decimal(string: "0.30")!,
                previousInflationRate: Decimal(string: "0.07")!,
                pendingInflationRate: Decimal(string: "0.07")!,
                previousStartDate: Date(timeIntervalSince1970: 1_700_000_000),
                pendingStartDate: Date(timeIntervalSince1970: 1_700_000_000),
                previousEndDate: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(86_400 * 365),
                pendingEndDate: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(86_400 * 365)
            )
        ]

        let outcome = try ledger.processBalanceUpdate(
            state: state,
            newBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )

        guard case .openCreditCreated(let next, let entry) = outcome else {
            return XCTFail("Expected open credit with suggested split")
        }

        XCTAssertTrue(next.heldGoalChanges.isEmpty, "Pending edits clear when the open entry is written")
        XCTAssertEqual(next.goals.first { $0.id == carID }?.shareOfNewCredits, Decimal(string: "0.70")!)
        XCTAssertEqual(next.goals.first { $0.id == emergencyID }?.shareOfNewCredits, Decimal(string: "0.30")!)

        let carAlloc = try XCTUnwrap(entry.allocations.first { $0.goalId == carID })
        let emergencyAlloc = try XCTUnwrap(entry.allocations.first { $0.goalId == emergencyID })
        XCTAssertEqual(carAlloc.percentage, Decimal(string: "0.70")!)
        XCTAssertEqual(emergencyAlloc.percentage, Decimal(string: "0.30")!)
        XCTAssertEqual(carAlloc.amount, 700_000)
        XCTAssertEqual(emergencyAlloc.amount, 300_000)
        XCTAssertFalse(entry.isLocked)
        XCTAssertTrue(ledger.isSyncOrUpdateBlocked(history: next.history))
    }

    func testSameBalanceDoesNotClearPendingEditsOrWriteHistory() throws {
        var state = samplePostSetupState()
        state.heldGoalChanges = [sampleHeldChange(goalId: carID, pendingShare: Decimal(string: "0.70")!)]
        let beforeCount = state.history.count

        let outcome = try ledger.processBalanceUpdate(
            state: state,
            newBalance: 10_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )

        guard case .noNewCredit = outcome else {
            return XCTFail("Expected same-balance no-op")
        }
        XCTAssertEqual(state.heldGoalChanges.count, 1, "Pending edits stay until an entry is written")
        XCTAssertEqual(state.history.count, beforeCount)
    }

    func testLowerBalanceDoesNotClearPendingEdits() throws {
        var state = samplePostSetupState()
        state.heldGoalChanges = [sampleHeldChange(goalId: carID, pendingShare: Decimal(string: "0.70")!)]

        let outcome = try ledger.processBalanceUpdate(
            state: state,
            newBalance: 9_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: true,
            id: entryID,
            createdAt: createdAt
        )

        guard case .withdrawalRequired(let shortfall, let previous, let newBalance) = outcome else {
            return XCTFail("Expected withdrawal path")
        }
        XCTAssertEqual(shortfall, 1_000_000)
        XCTAssertEqual(previous, 10_000_000)
        XCTAssertEqual(newBalance, 9_000_000)
        XCTAssertEqual(
            outcome.withdrawalPresentation,
            WithdrawalPresentation(
                shortfall: 1_000_000,
                previousBalance: 10_000_000,
                newBalance: 9_000_000
            )
        )
        XCTAssertEqual(state.heldGoalChanges.count, 1)
    }

    /// PIP-107 — Sync/Update lower path completes via `StubLedgerEngine.withdraw` → History.
    func testWithdrawalRequiredThenWithdrawViaEngineLocksHistory() throws {
        let state = samplePostSetupState()
        let outcome = try ledger.processBalanceUpdate(
            state: state,
            newBalance: 9_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard let presentation = outcome.withdrawalPresentation else {
            return XCTFail("Expected withdrawalPresentation from lower balance")
        }

        let reductions = WithdrawalService.proportionalReductions(
            goals: state.goals,
            shortfall: presentation.shortfall
        )
        XCTAssertEqual(reductions.values.reduce(0, +), presentation.shortfall)
        XCTAssertTrue(
            WithdrawalService.canSave(
                reductions: reductions,
                goals: state.goals,
                shortfall: presentation.shortfall
            )
        )

        let next = try ledger.withdraw(
            state: state,
            shortfall: presentation.shortfall,
            previousBalance: presentation.previousBalance,
            newBalance: presentation.newBalance,
            reductions: reductions,
            entryID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            now: createdAt
        )

        XCTAssertEqual(next.accounts.first(where: \.isDedicated)?.balance, presentation.newBalance)
        XCTAssertEqual(next.history.last?.type, .withdrawal)
        XCTAssertEqual(next.history.last?.withdrawalAmount, presentation.shortfall)
        XCTAssertTrue(next.history.last?.isLocked ?? false)
        XCTAssertEqual(next.standingSplits, state.standingSplits)
        // Credit was never written — Day-1 Sync block (F<P) holds until withdrawal completes.
        XCTAssertNil(ledger.openCreditEntry(in: next.history))
        XCTAssertFalse(ledger.isSyncOrUpdateBlocked(history: next.history))
    }

    // MARK: - No Sync while open

    func testOpenEntryBlocksSync() throws {
        var state = samplePostSetupState()
        let first = try ledger.processBalanceUpdate(
            state: state,
            newBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let withOpen, _) = first else {
            return XCTFail("Expected first open credit")
        }
        state = withOpen
        XCTAssertTrue(ledger.isSyncOrUpdateBlocked(history: state.history))

        XCTAssertThrowsError(
            try ledger.processBalanceUpdate(
                state: state,
                newBalance: 12_000_000,
                dedicatedAccountID: hdfcID,
                isTyped: false,
                id: UUID(),
                createdAt: createdAt
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertTrue(validation.message.contains("open credit"))
        }
    }

    func testTypedUpdateSetsIsTypedOnOpenEntry() throws {
        let outcome = try ledger.processBalanceUpdate(
            state: samplePostSetupState(),
            newBalance: 12_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: true,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(_, let entry) = outcome else {
            return XCTFail("Expected open credit")
        }
        XCTAssertEqual(entry.isTyped, true)
        XCTAssertEqual(entry.creditAmount, 2_000_000)
    }

    func testSuggestedSplitPercentagesMatchStanding() {
        let goals = sampleGoals(savedCar: 6_000_000, savedEmergency: 4_000_000)
        let standing = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.55")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.45")!)
        ]
        let map = ledger.suggestedSplitPercentages(goals: goals, standingSplits: standing)
        XCTAssertEqual(map[carID], Decimal(string: "0.55")!)
        XCTAssertEqual(map[emergencyID], Decimal(string: "0.45")!)
    }

    func testApplyPendingEditsAloneClearsHeldAndUpdatesShares() {
        var state = samplePostSetupState()
        state.heldGoalChanges = [
            sampleHeldChange(goalId: carID, pendingShare: Decimal(string: "0.70")!),
            sampleHeldChange(
                goalId: emergencyID,
                pendingShare: Decimal(string: "0.30")!,
                name: "Emergency Fund",
                previousShare: Decimal(string: "0.40")!
            )
        ]
        let next = GoalHeldChangeService.applyPendingEdits(to: state, now: createdAt)
        XCTAssertTrue(next.heldGoalChanges.isEmpty)
        XCTAssertEqual(next.goals.first { $0.id == carID }?.shareOfNewCredits, Decimal(string: "0.70")!)
        XCTAssertEqual(next.goals.first { $0.id == emergencyID }?.shareOfNewCredits, Decimal(string: "0.30")!)
        XCTAssertEqual(
            next.standingSplits.first { $0.goalId == carID }?.percentage,
            Decimal(string: "0.70")!
        )
    }

    // MARK: - Fixtures

    private func sampleHeldChange(
        goalId: UUID,
        pendingShare: Decimal,
        name: String = "Car",
        previousShare: Decimal = Decimal(string: "0.60")!
    ) -> HeldGoalChange {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400 * 365)
        return HeldGoalChange(
            id: UUID(),
            goalId: goalId,
            savedAt: createdAt.addingTimeInterval(-30),
            previousName: name,
            pendingName: name,
            previousTargetAmount: 50_000_000,
            pendingTargetAmount: 50_000_000,
            previousShareOfNewCredits: previousShare,
            pendingShareOfNewCredits: pendingShare,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.07")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )
    }

    private func sampleGoals(savedCar: Paisa, savedEmergency: Paisa) -> [Goal] {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400 * 365)
        return [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: start,
                endDate: end,
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: savedCar,
                shareOfNewCredits: Decimal(string: "0.60")!,
                createdAt: start,
                updatedAt: start
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: start,
                endDate: end,
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: savedEmergency,
                shareOfNewCredits: Decimal(string: "0.40")!,
                createdAt: start,
                updatedAt: start
            )
        ]
    }

    private func samplePostSetupState() -> PersistedAppState {
        let goals = sampleGoals(savedCar: 6_000_000, savedEmergency: 4_000_000)
        let opening = HistoryEntry(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
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
                    goalId: carID,
                    goalName: "Car",
                    amount: 6_000_000,
                    percentage: Decimal(string: "0.60")!
                ),
                GoalAllocation(
                    goalId: emergencyID,
                    goalName: "Emergency Fund",
                    amount: 4_000_000,
                    percentage: Decimal(string: "0.40")!
                )
            ]
        )
        return PersistedAppState(
            accounts: [
                Account(
                    id: hdfcID,
                    bankName: "HDFC",
                    maskedNumber: "••4821",
                    balance: 10_000_000,
                    isDedicated: true,
                    isPaytmLinked: true,
                    consentAutoUpdate: true
                )
            ],
            goals: goals,
            history: [opening],
            standingSplits: [
                StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
            ]
        )
    }
}
