import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class CreditEntryServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_100)

    // MARK: - Balance compare (R7 / R26 / 10b)

    func testHigherBalanceProducesCreditAmount() {
        let result = CreditEntryService.compare(
            previousBalance: 10_000_000,
            newBalance: 11_000_000
        )
        XCTAssertEqual(
            result,
            .higher(
                creditAmount: 1_000_000,
                previousBalance: 10_000_000,
                newBalance: 11_000_000
            )
        )
    }

    func testSameBalanceIsNoOp() {
        XCTAssertEqual(
            CreditEntryService.compare(previousBalance: 10_000_000, newBalance: 10_000_000),
            .same
        )
        XCTAssertEqual(
            CreditEntryService.noNewCreditMessage,
            "No new credit since the last sync."
        )
    }

    func testLowerBalanceProducesShortfall() {
        let result = CreditEntryService.compare(
            previousBalance: 10_000_000,
            newBalance: 9_000_000
        )
        XCTAssertEqual(
            result,
            .lower(
                shortfall: 1_000_000,
                previousBalance: 10_000_000,
                newBalance: 9_000_000
            )
        )
    }

    // MARK: - Split validation (BR-2 / this-credit defaults)

    func testDefaultPercentagesFromStandingSplit() {
        let goals = sampleGoals(savedCar: 6_000_000, savedEmergency: 4_000_000)
        let standing = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
        ]
        let map = CreditEntryService.defaultPercentages(goals: goals, standingSplits: standing)
        XCTAssertEqual(map[carID], Decimal(string: "0.60")!)
        XCTAssertEqual(map[emergencyID], Decimal(string: "0.40")!)
        XCTAssertTrue(OpeningSplitService.isValidHundredPercent(Array(map.values)))
    }

    func testSingleGoalAutoAssignsHundredPercent() {
        let goal = sampleGoals(savedCar: 10_000_000, savedEmergency: 0)[0]
        let map = CreditEntryService.defaultPercentages(goals: [goal], standingSplits: [])
        XCTAssertEqual(map[carID], Decimal(1))
        XCTAssertTrue(OpeningSplitService.isValidHundredPercent(Array(map.values)))
    }

    func testCanSaveRequiresHundredPercentAndOpenEntry() throws {
        let entry = try sampleOpenEntry()
        XCTAssertTrue(
            CreditEntryService.canSaveAndLock(
                entry: entry,
                fractions: [Decimal(string: "0.60")!, Decimal(string: "0.40")!]
            )
        )
        XCTAssertFalse(
            CreditEntryService.canSaveAndLock(
                entry: entry,
                fractions: [Decimal(string: "0.50")!, Decimal(string: "0.30")!]
            )
        )
        var locked = entry
        locked.isLocked = true
        XCTAssertFalse(
            CreditEntryService.canSaveAndLock(
                entry: locked,
                fractions: [Decimal(string: "0.60")!, Decimal(string: "0.40")!]
            )
        )
    }

    // MARK: - Entry state machine (open → lock / BR-5 / BR-6)

    func testProcessFetchedHigherCreatesOpenEntry() throws {
        let state = samplePostSetupState()
        let outcome = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )

        guard case .openCreditCreated(let next, let entry) = outcome else {
            return XCTFail("Expected open credit")
        }
        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .newCredit)
        XCTAssertFalse(entry.isLocked)
        XCTAssertEqual(entry.creditAmount, 1_000_000)
        XCTAssertEqual(entry.previousBalance, 10_000_000)
        XCTAssertEqual(entry.newBalance, 11_000_000)
        XCTAssertEqual(entry.isTyped, false)
        XCTAssertEqual(entry.allocations.map(\.amount).reduce(0, +), 1_000_000)
        XCTAssertEqual(
            AccountsService.dedicatedAccount(in: next.accounts)?.balance,
            11_000_000
        )
        XCTAssertTrue(CreditEntryService.isSyncOrUpdateBlocked(history: next.history))
        XCTAssertEqual(CreditEntryService.openCreditEntry(in: next.history)?.id, entryID)
    }

    func testProcessFetchedSameReturnsNoNewCreditWithoutHistoryWrite() throws {
        let state = samplePostSetupState()
        let outcome = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 10_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false
        )
        guard case .noNewCredit(let message) = outcome else {
            return XCTFail("Expected same-balance no-op")
        }
        XCTAssertEqual(message, CreditEntryService.noNewCreditMessage)
        XCTAssertEqual(state.history.count, 1) // opening only; unchanged by value semantics
    }

    func testProcessFetchedLowerTriggersWithdrawalOutcome() throws {
        let state = samplePostSetupState()
        let outcome = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 8_500_000,
            dedicatedAccountID: hdfcID,
            isTyped: false
        )
        guard case .withdrawalRequired(let shortfall, let previous, let newBalance) = outcome else {
            return XCTFail("Expected withdrawal")
        }
        XCTAssertEqual(shortfall, 1_500_000)
        XCTAssertEqual(previous, 10_000_000)
        XCTAssertEqual(newBalance, 8_500_000)
        XCTAssertNil(CreditEntryService.openCreditEntry(in: state.history))
    }

    func testTypedCreditSetsIsTypedFlag() throws {
        let state = samplePostSetupState()
        let outcome = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 12_000_000,
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

    func testOpenEntryBlocksSecondSync() throws {
        var state = samplePostSetupState()
        let first = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let withOpen, _) = first else {
            return XCTFail("Expected first open credit")
        }
        state = withOpen
        XCTAssertTrue(CreditEntryService.isSyncOrUpdateBlocked(history: state.history))

        XCTAssertThrowsError(
            try CreditEntryService.processFetchedBalance(
                state: state,
                fetchedBalance: 12_000_000,
                dedicatedAccountID: hdfcID,
                isTyped: false
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertTrue(validation.message.contains("open credit"))
        }
    }

    func testSaveAndLockUpdatesSavedAmountsAndFreezesEntry() throws {
        var state = samplePostSetupState()
        let created = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let withOpen, _) = created else {
            return XCTFail("Expected open credit")
        }
        state = withOpen

        state = try CreditEntryService.applyCreditLock(
            to: state,
            entryID: entryID,
            percentages: [
                carID: Decimal(string: "0.70")!,
                emergencyID: Decimal(string: "0.30")!
            ],
            useThisSplitForStanding: false,
            now: createdAt
        )

        let locked = try XCTUnwrap(state.history.first { $0.id == entryID })
        XCTAssertTrue(locked.isLocked)
        XCTAssertEqual(locked.allocations.map(\.amount).reduce(0, +), 1_000_000)

        let car = try XCTUnwrap(state.goals.first { $0.id == carID })
        let emergency = try XCTUnwrap(state.goals.first { $0.id == emergencyID })
        // Prior saved 60k/40k + this credit 7k/3k
        XCTAssertEqual(car.savedAmount, 6_700_000)
        XCTAssertEqual(emergency.savedAmount, 4_300_000)
        // Standing unchanged when checkbox off
        XCTAssertEqual(car.shareOfNewCredits, Decimal(string: "0.60")!)
        XCTAssertEqual(
            state.standingSplits.first { $0.goalId == carID }?.percentage,
            Decimal(string: "0.60")!
        )

        XCTAssertFalse(CreditEntryService.isSyncOrUpdateBlocked(history: state.history))
        XCTAssertNil(CreditEntryService.openCreditEntry(in: state.history))

        // BR-5: second lock rejected
        XCTAssertThrowsError(
            try CreditEntryService.applyCreditLock(
                to: state,
                entryID: entryID,
                percentages: [
                    carID: Decimal(string: "0.50")!,
                    emergencyID: Decimal(string: "0.50")!
                ],
                useThisSplitForStanding: false
            )
        )
    }

    func testUseThisSplitUpdatesStandingSplit() throws {
        var state = samplePostSetupState()
        let created = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let withOpen, _) = created else {
            return XCTFail("Expected open credit")
        }
        state = try CreditEntryService.applyCreditLock(
            to: withOpen,
            entryID: entryID,
            percentages: [
                carID: Decimal(string: "0.25")!,
                emergencyID: Decimal(string: "0.75")!
            ],
            useThisSplitForStanding: true,
            now: createdAt
        )

        XCTAssertEqual(
            state.standingSplits.first { $0.goalId == carID }?.percentage,
            Decimal(string: "0.25")!
        )
        XCTAssertEqual(
            state.standingSplits.first { $0.goalId == emergencyID }?.percentage,
            Decimal(string: "0.75")!
        )
        XCTAssertEqual(
            state.goals.first { $0.id == carID }?.shareOfNewCredits,
            Decimal(string: "0.25")!
        )
    }

    func testBannerMessageIncludesAmountAndAssignNow() {
        let formatting = FormattingService()
        let message = CreditEntryService.openEntryBannerMessage(
            creditAmount: 1_000_000,
            formatting: formatting
        )
        XCTAssertTrue(message.contains(CreditEntryService.openEntryBannerPrefix))
        XCTAssertTrue(message.contains(CreditEntryService.assignNowTitle))
        XCTAssertTrue(message.contains("₹10,000") || message.contains("10,000"))
    }

    // MARK: - Fixtures

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

    private func sampleOpenEntry() throws -> HistoryEntry {
        try CreditEntryService.createOpenCreditEntry(
            goals: sampleGoals(savedCar: 6_000_000, savedEmergency: 4_000_000),
            standingSplits: [
                StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
            ],
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            creditAmount: 1_000_000,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
    }
}
