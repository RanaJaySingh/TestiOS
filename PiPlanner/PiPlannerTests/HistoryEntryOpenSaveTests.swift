import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// PIP-103 — History entry open → save: customSplit, suggested standing, create goal, totals on Save only.
final class HistoryEntryOpenSaveTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_100)
    private let ledger: any LedgerEngine = StubLedgerEngine()

    // MARK: - Suggested standing + customSplit

    func testSuggestedStandingSplitMatchesDefaultPercentages() {
        let goals = sampleGoals(savedCar: 6_000_000, savedEmergency: 4_000_000)
        let standing = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
        ]
        let suggested = CreditEntryService.suggestedStandingPercentages(
            goals: goals,
            standingSplits: standing
        )
        XCTAssertEqual(suggested[carID], Decimal(string: "0.60")!)
        XCTAssertEqual(suggested[emergencyID], Decimal(string: "0.40")!)
        XCTAssertFalse(
            CreditEntryService.isCustomSplit(
                percentages: suggested,
                suggested: suggested
            )
        )
        XCTAssertTrue(
            CreditEntryService.isCustomSplit(
                percentages: [
                    carID: Decimal(string: "0.70")!,
                    emergencyID: Decimal(string: "0.30")!
                ],
                suggested: suggested
            )
        )
    }

    func testOpenCreditEntryStartsWithoutCustomSplitFlag() throws {
        let entry = try CreditEntryService.createOpenCreditEntry(
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
        XCTAssertFalse(entry.isLocked)
        XCTAssertNotEqual(entry.customSplit, true)
        XCTAssertEqual(entry.allocations.count, 2)
    }

    func testSaveSetsCustomSplitWhenPercentagesDifferFromSuggested() throws {
        var state = try openCreditState()
        let suggested = CreditEntryService.suggestedStandingPercentages(
            goals: state.goals,
            standingSplits: state.standingSplits
        )
        XCTAssertEqual(suggested[carID], Decimal(string: "0.60")!)

        state = try ledger.saveAndLockCredit(
            state: state,
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
        XCTAssertEqual(locked.customSplit, true)
    }

    func testSaveClearsCustomSplitWhenMatchingSuggestedStanding() throws {
        var state = try openCreditState()
        state = try ledger.saveAndLockCredit(
            state: state,
            entryID: entryID,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            useThisSplitForStanding: false,
            now: createdAt
        )
        let locked = try XCTUnwrap(state.history.first { $0.id == entryID })
        XCTAssertTrue(locked.isLocked)
        XCTAssertNotEqual(locked.customSplit, true)
    }

    func testGoalTotalsUpdateOnlyOnSaveNotOnOpen() throws {
        let before = samplePostSetupState()
        let carBefore = try XCTUnwrap(before.goals.first { $0.id == carID }?.savedAmount)
        let emergencyBefore = try XCTUnwrap(before.goals.first { $0.id == emergencyID }?.savedAmount)

        let opened = try ledger.openCreditFromFetchedBalance(
            state: before,
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let withOpen, _) = opened else {
            return XCTFail("Expected open credit")
        }
        XCTAssertEqual(withOpen.goals.first { $0.id == carID }?.savedAmount, carBefore)
        XCTAssertEqual(withOpen.goals.first { $0.id == emergencyID }?.savedAmount, emergencyBefore)

        let lockedState = try ledger.saveAndLockCredit(
            state: withOpen,
            entryID: entryID,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            useThisSplitForStanding: false,
            now: createdAt
        )
        XCTAssertEqual(lockedState.goals.first { $0.id == carID }?.savedAmount, carBefore + 600_000)
        XCTAssertEqual(
            lockedState.goals.first { $0.id == emergencyID }?.savedAmount,
            emergencyBefore + 400_000
        )
    }

    // MARK: - Create goal while open

    func testCreateGoalOnOpenEntryDoesNotChangeSavedTotals() throws {
        var state = try openCreditState()
        let carBefore = try XCTUnwrap(state.goals.first { $0.id == carID }?.savedAmount)
        let emergencyBefore = try XCTUnwrap(state.goals.first { $0.id == emergencyID }?.savedAmount)

        let newGoal = sampleVacationGoal()
        state = try CreditEntryService.addGoalToOpenCredit(
            to: state,
            entryID: entryID,
            goal: newGoal,
            now: createdAt
        )

        XCTAssertEqual(state.goals.count, 3)
        XCTAssertEqual(state.goals.first { $0.id == vacationID }?.savedAmount, 0)
        XCTAssertEqual(state.goals.first { $0.id == carID }?.savedAmount, carBefore)
        XCTAssertEqual(state.goals.first { $0.id == emergencyID }?.savedAmount, emergencyBefore)

        let open = try XCTUnwrap(state.history.first { $0.id == entryID })
        XCTAssertFalse(open.isLocked)
        XCTAssertEqual(open.allocations.count, 3)
        XCTAssertEqual(open.allocations.first { $0.goalId == vacationID }?.percentage, 0)
        XCTAssertEqual(
            open.allocations.map(\.percentage).reduce(Decimal(0), +),
            Decimal(1)
        )
    }

    func testCreateGoalThenCustomSaveLocksAndUpdatesTotals() throws {
        var state = try openCreditState()
        state = try CreditEntryService.addGoalToOpenCredit(
            to: state,
            entryID: entryID,
            goal: sampleVacationGoal(),
            now: createdAt
        )

        state = try ledger.saveAndLockCredit(
            state: state,
            entryID: entryID,
            percentages: [
                carID: Decimal(string: "0.50")!,
                emergencyID: Decimal(string: "0.30")!,
                vacationID: Decimal(string: "0.20")!
            ],
            useThisSplitForStanding: true,
            now: createdAt
        )

        let locked = try XCTUnwrap(state.history.first { $0.id == entryID })
        XCTAssertTrue(locked.isLocked)
        XCTAssertEqual(locked.customSplit, true)
        XCTAssertEqual(state.goals.first { $0.id == vacationID }?.savedAmount, 200_000)
        XCTAssertEqual(
            state.standingSplits.first { $0.goalId == vacationID }?.percentage,
            Decimal(string: "0.20")!
        )
    }

    func testHistoryServiceShowsCustomBadgeFromFlag() {
        var entry = HistoryEntry(
            id: entryID,
            type: .newCredit,
            createdAt: createdAt,
            isLocked: true,
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            creditAmount: 1_000_000,
            isTyped: false,
            customSplit: true,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
        XCTAssertTrue(HistoryService.showsCustomSplitBadge(entry))
        entry.customSplit = false
        entry.isTyped = true
        XCTAssertFalse(HistoryService.showsCustomSplitBadge(entry))
        XCTAssertTrue(HistoryService.showsTypedBadge(entry))
    }

    // MARK: - Fixtures

    private func openCreditState() throws -> PersistedAppState {
        let outcome = try ledger.openCreditFromFetchedBalance(
            state: samplePostSetupState(),
            fetchedBalance: 11_000_000,
            dedicatedAccountID: hdfcID,
            isTyped: false,
            id: entryID,
            createdAt: createdAt
        )
        guard case .openCreditCreated(let state, _) = outcome else {
            throw NSError(domain: "test", code: 1)
        }
        return state
    }

    private func sampleVacationGoal() -> Goal {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return Goal(
            id: vacationID,
            name: "Vacation",
            targetAmount: 5_000_000,
            startDate: start,
            endDate: start.addingTimeInterval(86_400 * 180),
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 0,
            shareOfNewCredits: 0,
            createdAt: start,
            updatedAt: start
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
