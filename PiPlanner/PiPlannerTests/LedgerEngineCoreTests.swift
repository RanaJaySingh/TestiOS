import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class LedgerEngineCoreTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let vacationID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let hdfcID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let entryID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar { .gregorianUTC }

    // MARK: - Formulas

    func testAdjustedTargetUsesMonthsOverTwelve() {
        let start = date(2026, 1, 1)
        let end = date(2027, 1, 1) // 12 months → exponent 1.0
        let target: Paisa = 10_000_000 // ₹1,00,000
        let inflation = Decimal(string: "0.07")!

        let adjusted = LedgerEngineCore.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: inflation,
            startDate: start,
            endDate: end,
            calendar: calendar
        )
        let expected = Paisa((Double(target) * pow(1.07, 1.0)).rounded())
        XCTAssertEqual(adjusted, expected)

        let sixMonths = LedgerEngineCore.adjustedTargetPaisa(
            targetPaisa: target,
            inflationRate: inflation,
            startDate: start,
            endDate: date(2026, 7, 1),
            calendar: calendar
        )
        let expectedHalf = Paisa((Double(target) * pow(1.07, 0.5)).rounded())
        XCTAssertEqual(sixMonths, expectedHalf)
        XCTAssertEqual(
            LedgerEngineCore.monthsBetween(start: start, end: date(2026, 7, 1), calendar: calendar),
            6
        )
    }

    func testRequiredSavingsDividesRemainingByMonthsLeft() {
        let end = date(2026, 7, 1)
        let asOf = date(2026, 1, 1) // 6 months remaining
        let required = LedgerEngineCore.requiredSavingsPaisa(
            adjustedTarget: 1_200_000,
            currentSaving: 200_000,
            endDate: end,
            asOf: asOf,
            calendar: calendar
        )
        XCTAssertEqual(required, 1_000_000 / 6)
    }

    func testOnTrackStatusWhenSavedMeetsExpected() {
        let start = date(2026, 1, 1)
        let end = date(2027, 1, 1)
        let asOf = date(2026, 4, 1) // 3 months elapsed, 9 remaining
        // Save enough that cumulative required-to-date is covered → on track.
        let onTrack = makeGoal(
            id: carID,
            name: "Car",
            target: 1_200_000,
            saved: 1_200_000,
            start: start,
            end: end,
            inflation: 0
        )
        XCTAssertEqual(LedgerEngineCore.status(for: onTrack, asOf: asOf, calendar: calendar), .onTrack)

        let behind = makeGoal(
            id: carID,
            name: "Car",
            target: 1_200_000,
            saved: 0,
            start: start,
            end: end,
            inflation: 0
        )
        let monthly = LedgerEngineCore.requiredSavingsPaisa(for: behind, asOf: asOf, calendar: calendar)
        XCTAssertEqual(
            LedgerEngineCore.status(for: behind, asOf: asOf, calendar: calendar),
            .behind(shortfall: monthly * 3)
        )
    }

    func testGoalComputedPropertiesMatchLedgerEngine() {
        let goal = makeGoal(
            id: carID,
            name: "Car",
            target: 10_000_000,
            saved: 1_000_000,
            start: date(2026, 1, 1),
            end: date(2028, 1, 1),
            inflation: Decimal(string: "0.07")!
        )
        XCTAssertEqual(
            goal.adjustedTarget,
            LedgerEngineCore.adjustedTargetPaisa(
                targetPaisa: goal.targetAmount,
                inflationRate: goal.inflationRate,
                startDate: goal.startDate,
                endDate: goal.endDate
            )
        )
    }

    // MARK: - Snapshot / delta

    func testFetchedHigherBalanceOpensCreditWithIsTypedFalse() throws {
        var state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let outcome = try LedgerEngineCore.applyBalanceDelta(
            to: state,
            newBalance: 11_000_000,
            source: .fetched,
            dedicatedAccountID: hdfcID,
            id: entryID,
            createdAt: now
        )
        guard case let .openCreditCreated(next, entry) = outcome else {
            return XCTFail("Expected open credit")
        }
        XCTAssertEqual(entry.isTyped, false)
        XCTAssertFalse(entry.isLocked)
        XCTAssertEqual(entry.creditAmount, 1_000_000)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: next.history))
        XCTAssertEqual(LedgerEngineCore.openCreditEntry(in: next.history)?.id, entryID)
        state = next
    }

    func testTypedHigherBalanceOpensCreditWithIsTypedTrue() throws {
        let state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let outcome = try LedgerEngineCore.applyBalanceDelta(
            to: state,
            newBalance: 12_000_000,
            source: .typed,
            dedicatedAccountID: hdfcID,
            id: entryID,
            createdAt: now
        )
        guard case let .openCreditCreated(_, entry) = outcome else {
            return XCTFail("Expected open credit")
        }
        XCTAssertEqual(entry.isTyped, true)
        XCTAssertEqual(
            LedgerEngineCore.compare(
                LedgerEngineCore.BalanceSnapshot(
                    previousBalance: 10_000_000,
                    newBalance: 12_000_000,
                    source: .typed
                )
            ),
            .higher(creditAmount: 2_000_000, previousBalance: 10_000_000, newBalance: 12_000_000)
        )
    }

    func testSameBalanceIsNoOpAndLowerRequiresWithdrawal() throws {
        let state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let same = try LedgerEngineCore.applyBalanceDelta(
            to: state,
            newBalance: 10_000_000,
            source: .fetched,
            dedicatedAccountID: hdfcID
        )
        XCTAssertEqual(same, .noNewCredit(message: CreditEntryService.noNewCreditMessage))

        let lower = try LedgerEngineCore.applyBalanceDelta(
            to: state,
            newBalance: 9_000_000,
            source: .typed,
            dedicatedAccountID: hdfcID
        )
        XCTAssertEqual(
            lower,
            .withdrawalRequired(
                shortfall: 1_000_000,
                previousBalance: 10_000_000,
                newBalance: 9_000_000
            )
        )
    }

    // MARK: - History open → save; append-only

    func testOpenCreditSaveLocksAndAppendOnlyPreservesPriorSlices() throws {
        var state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        // Seed a locked opening slice
        let opening = try OpeningSplitService.createLockedOpeningEntry(
            goals: state.goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            createdAt: now.addingTimeInterval(-3_600)
        )
        state.history = [opening]
        let lockedBefore = LedgerEngineCore.lockedSlices(in: state.history)

        let opened = try LedgerEngineCore.applyBalanceDelta(
            to: state,
            newBalance: 11_000_000,
            source: .fetched,
            dedicatedAccountID: hdfcID,
            id: entryID,
            createdAt: now
        )
        guard case let .openCreditCreated(withOpen, _) = opened else {
            return XCTFail("Expected open credit")
        }

        let percentages: [UUID: Decimal] = [
            carID: Decimal(string: "0.70")!,
            emergencyID: Decimal(string: "0.30")!
        ]
        let locked = try LedgerEngineCore.saveOpenCredit(
            to: withOpen,
            entryID: entryID,
            percentages: percentages,
            useThisSplitForStanding: true,
            now: now
        )

        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: locked.history))
        XCTAssertEqual(LedgerEngineCore.lockedSlices(in: locked.history).first, lockedBefore.first)
        XCTAssertNil(LedgerEngineCore.openCreditEntry(in: locked.history))
        XCTAssertEqual(locked.history.first(where: { $0.id == entryID })?.isLocked, true)
        XCTAssertEqual(locked.goals.first(where: { $0.id == carID })?.savedAmount, 6_000_000 + 700_000)
        XCTAssertEqual(locked.goals.first(where: { $0.id == emergencyID })?.savedAmount, 4_000_000 + 300_000)
    }

    func testIsAppendOnlyRejectsMutatingLockedSlice() {
        let locked = HistoryEntry(
            id: entryID,
            type: .openingBalance,
            createdAt: now,
            isLocked: true,
            previousBalance: nil,
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
        var mutated = locked
        mutated.creditAmount = 999
        XCTAssertFalse(LedgerEngineCore.isAppendOnlyMutation(before: [locked], after: [mutated]))
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: [locked], after: [locked]))
    }

    // MARK: - Standing split (1 goal = 100%)

    func testSingleGoalStandingIsHundredPercent() throws {
        var state = PersistedAppState.empty
        state.accounts = [dedicatedAccount(balance: 0)]
        state = try LedgerEngineCore.createGoal(
            to: state,
            name: "Emergency",
            targetPaisa: 5_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2027, 1, 1),
            id: emergencyID,
            now: now
        )
        XCTAssertEqual(state.goals.count, 1)
        XCTAssertEqual(state.standingSplits.count, 1)
        XCTAssertEqual(state.standingSplits[0].percentage, 1)
        XCTAssertEqual(state.goals[0].shareOfNewCredits, 1)

        let map = LedgerEngineCore.singleGoalStandingPercentages(goalID: emergencyID)
        XCTAssertEqual(map[emergencyID], 1)
    }

    // MARK: - Create / update / transfer / delete / withdrawal

    func testCreateGoalAppendsWithZeroSaved() throws {
        var state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        state = try LedgerEngineCore.createGoal(
            to: state,
            name: "Vacation",
            targetPaisa: 2_000_000,
            startDate: date(2026, 1, 1),
            endDate: date(2026, 12, 1),
            id: vacationID,
            now: now
        )
        XCTAssertEqual(state.goals.count, 3)
        XCTAssertEqual(state.goals.first(where: { $0.id == vacationID })?.savedAmount, 0)
        XCTAssertTrue(state.standingSplits.contains { $0.goalId == vacationID && $0.percentage == 0 })
    }

    func testUpdateGoalPendingLeavesHistoryIntact() throws {
        var state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let opening = try OpeningSplitService.createLockedOpeningEntry(
            goals: state.goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            createdAt: now
        )
        state.history = [opening]
        let historyBefore = state.history

        var draft = GoalEditDraft(goal: state.goals.first(where: { $0.id == carID })!)
        draft.name = "Car upgrade"
        draft.targetRupeeDigits = "150000" // ₹1,50,000 → 15_000_000 paisa
        draft.endDate = date(2028, 1, 1)
        state = try LedgerEngineCore.updateGoalPending(
            to: state,
            goalID: carID,
            draft: draft,
            now: now
        )
        XCTAssertEqual(state.history, historyBefore)
        XCTAssertEqual(state.goals.first(where: { $0.id == carID })?.name, "Car upgrade")
        XCTAssertEqual(state.goals.first(where: { $0.id == carID })?.savedAmount, 6_000_000)
        XCTAssertTrue(state.heldGoalChanges.contains { $0.goalId == carID })
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: historyBefore, after: state.history))
    }

    func testTransferMovesSavedWithoutChangingStanding() throws {
        let state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let standingBefore = state.standingSplits
        let next = try LedgerEngineCore.transfer(
            to: state,
            fromGoalId: carID,
            toGoalId: emergencyID,
            amountPaisa: 500_000,
            entryID: entryID,
            now: now
        )
        XCTAssertEqual(next.goals.first(where: { $0.id == carID })?.savedAmount, 5_500_000)
        XCTAssertEqual(next.goals.first(where: { $0.id == emergencyID })?.savedAmount, 4_500_000)
        XCTAssertEqual(next.standingSplits, standingBefore)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: next.history))
        XCTAssertEqual(next.history.last?.type, .transfer)
        XCTAssertEqual(next.history.last?.isLocked, true)
    }

    func testDeleteRedistributesSavedAndAppendsHistory() throws {
        let state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let percentages: [UUID: Decimal] = [emergencyID: 1]
        let next = try LedgerEngineCore.deleteRedistributing(
            to: state,
            deletingGoalID: carID,
            percentages: percentages,
            entryID: entryID,
            now: now
        )
        XCTAssertEqual(next.goals.map(\.id), [emergencyID])
        XCTAssertEqual(next.goals[0].savedAmount, 10_000_000)
        XCTAssertEqual(next.history.last?.type, .goalDeleted)
        XCTAssertEqual(next.history.last?.releasedAmount, 6_000_000)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: next.history))
    }

    func testWithdrawalReducesGoalsAndBalance() throws {
        let state = baseState(balance: 10_000_000, savedCar: 6_000_000, savedEmergency: 4_000_000)
        let reductions: [UUID: Paisa] = [
            carID: 600_000,
            emergencyID: 400_000
        ]
        let next = try LedgerEngineCore.withdraw(
            to: state,
            shortfall: 1_000_000,
            previousBalance: 10_000_000,
            newBalance: 9_000_000,
            reductions: reductions,
            entryID: entryID,
            now: now
        )
        XCTAssertEqual(next.accounts.first(where: \.isDedicated)?.balance, 9_000_000)
        XCTAssertEqual(next.goals.first(where: { $0.id == carID })?.savedAmount, 5_400_000)
        XCTAssertEqual(next.goals.first(where: { $0.id == emergencyID })?.savedAmount, 3_600_000)
        XCTAssertEqual(next.standingSplits, state.standingSplits)
        XCTAssertEqual(next.history.last?.type, .withdrawal)
        XCTAssertTrue(LedgerEngineCore.isAppendOnlyMutation(before: state.history, after: next.history))
    }

    // MARK: - Fixtures

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        return calendar.date(from: components)!
    }

    private func dedicatedAccount(balance: Paisa) -> Account {
        Account(
            id: hdfcID,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: balance,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: true
        )
    }

    private func makeGoal(
        id: UUID,
        name: String,
        target: Paisa,
        saved: Paisa,
        start: Date,
        end: Date,
        inflation: Decimal,
        share: Decimal = Decimal(string: "0.50")!
    ) -> Goal {
        Goal(
            id: id,
            name: name,
            targetAmount: target,
            startDate: start,
            endDate: end,
            inflationRate: inflation,
            savedAmount: saved,
            shareOfNewCredits: share,
            createdAt: now,
            updatedAt: now
        )
    }

    private func baseState(balance: Paisa, savedCar: Paisa, savedEmergency: Paisa) -> PersistedAppState {
        let goals = [
            makeGoal(
                id: carID,
                name: "Car",
                target: 20_000_000,
                saved: savedCar,
                start: date(2026, 1, 1),
                end: date(2028, 1, 1),
                inflation: Decimal(string: "0.07")!,
                share: Decimal(string: "0.60")!
            ),
            makeGoal(
                id: emergencyID,
                name: "Emergency",
                target: 10_000_000,
                saved: savedEmergency,
                start: date(2026, 1, 1),
                end: date(2027, 1, 1),
                inflation: Decimal(string: "0.07")!,
                share: Decimal(string: "0.40")!
            )
        ]
        return PersistedAppState(
            accounts: [dedicatedAccount(balance: balance)],
            goals: goals,
            history: [],
            standingSplits: [
                StandingSplit(goalId: carID, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.40")!)
            ],
            heldGoalChanges: []
        )
    }
}
