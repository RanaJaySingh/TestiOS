import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class OpeningSplitServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - 100% validation (BR-2 / R22)

    func testMultiGoalPercentsMustSumToExactly100ToBeValid() {
        XCTAssertFalse(
            OpeningSplitService.isValidHundredPercent([
                Decimal(string: "0.60")!,
                Decimal(string: "0.30")!
            ])
        )
        XCTAssertTrue(
            OpeningSplitService.isValidHundredPercent([
                Decimal(string: "0.60")!,
                Decimal(string: "0.40")!
            ])
        )
        XCTAssertFalse(OpeningSplitService.isValidHundredPercent([]))
    }

    func testShortfallMessageWhenBelowHundred() {
        let message = OpeningSplitService.shortfallMessage(for: [
            Decimal(string: "0.60")!,
            Decimal(string: "0.20")!
        ])
        XCTAssertEqual(message, "Total 80%. Assign the remaining 20%.")
    }

    func testShortfallMessageNilWhenExactlyHundred() {
        XCTAssertNil(
            OpeningSplitService.shortfallMessage(for: [
                Decimal(string: "1.0")!
            ])
        )
    }

    func testSingleGoalAutoHundredPercent() {
        let map = OpeningSplitService.singleGoalPercentages(goalID: carID)
        XCTAssertEqual(map[carID], Decimal(1))
        XCTAssertTrue(OpeningSplitService.isValidHundredPercent(Array(map.values)))
    }

    func testShouldPresentEditorOnlyForTwoOrMoreGoals() {
        XCTAssertFalse(OpeningSplitService.shouldPresentEditor(goalCount: 0))
        XCTAssertFalse(OpeningSplitService.shouldPresentEditor(goalCount: 1))
        XCTAssertTrue(OpeningSplitService.shouldPresentEditor(goalCount: 2))
        XCTAssertTrue(OpeningSplitService.shouldPresentEditor(goalCount: 3))
    }

    // MARK: - History entry creation (R6 / BR-3)

    func testCreateLockedOpeningEntryAllocationsAndLock() throws {
        let goals = sampleGoals()
        let percentages: [UUID: Decimal] = [
            carID: Decimal(string: "0.60")!,
            emergencyID: Decimal(string: "0.40")!
        ]
        let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

        let entry = try OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: percentages,
            id: entryID,
            createdAt: createdAt
        )

        XCTAssertEqual(entry.id, entryID)
        XCTAssertEqual(entry.type, .openingBalance)
        XCTAssertTrue(entry.isLocked)
        XCTAssertEqual(entry.creditAmount, 10_000_000)
        XCTAssertEqual(entry.newBalance, 10_000_000)
        XCTAssertEqual(entry.allocations.count, 2)
        XCTAssertEqual(entry.allocations.map(\.amount).reduce(0, +), 10_000_000)

        let car = try XCTUnwrap(entry.allocations.first { $0.goalId == carID })
        let emergency = try XCTUnwrap(entry.allocations.first { $0.goalId == emergencyID })
        XCTAssertEqual(car.amount, 6_000_000)
        XCTAssertEqual(emergency.amount, 4_000_000)
        XCTAssertEqual(car.goalName, "Car")
        XCTAssertEqual(emergency.goalName, "Emergency Fund")
        XCTAssertEqual(car.percentage, Decimal(string: "0.60")!)
        XCTAssertEqual(emergency.percentage, Decimal(string: "0.40")!)
    }

    func testCreateLockedOpeningEntryRejectsWhenNotHundred() {
        let goals = sampleGoals()
        XCTAssertThrowsError(
            try OpeningSplitService.createLockedOpeningEntry(
                goals: goals,
                openingBalance: 10_000_000,
                percentages: [
                    carID: Decimal(string: "0.50")!,
                    emergencyID: Decimal(string: "0.30")!
                ]
            )
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertEqual(validation.code, .splitNotHundred)
        }
    }

    func testApplyOpeningLockUpdatesGoalsStandingSplitsAndHistory() throws {
        let goals = sampleGoals()
        let entry = try OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ],
            id: UUID(),
            createdAt: createdAt
        )

        let state = PersistedAppState(
            accounts: [],
            goals: goals,
            history: [],
            standingSplits: []
        )
        let next = try OpeningSplitService.applyOpeningLock(to: state, entry: entry, now: createdAt)

        XCTAssertEqual(next.history.count, 1)
        XCTAssertEqual(next.history[0].type, .openingBalance)
        XCTAssertTrue(next.history[0].isLocked)

        let car = try XCTUnwrap(next.goals.first { $0.id == carID })
        let emergency = try XCTUnwrap(next.goals.first { $0.id == emergencyID })
        XCTAssertEqual(car.savedAmount, 6_000_000)
        XCTAssertEqual(emergency.savedAmount, 4_000_000)
        XCTAssertEqual(car.shareOfNewCredits, Decimal(string: "0.60")!)
        XCTAssertEqual(emergency.shareOfNewCredits, Decimal(string: "0.40")!)
        XCTAssertEqual(next.standingSplits.count, 2)
        XCTAssertEqual(
            Set(next.standingSplits.map(\.percentage)),
            Set([Decimal(string: "0.60")!, Decimal(string: "0.40")!])
        )
    }

    func testApplyOpeningLockIsRejectedWhenOpeningAlreadyLocked() throws {
        let goals = sampleGoals()
        let entry = try OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                carID: Decimal(string: "0.60")!,
                emergencyID: Decimal(string: "0.40")!
            ]
        )
        var state = PersistedAppState(accounts: [], goals: goals, history: [], standingSplits: [])
        state = try OpeningSplitService.applyOpeningLock(to: state, entry: entry)

        XCTAssertThrowsError(
            try OpeningSplitService.applyOpeningLock(to: state, entry: entry)
        ) { error in
            guard case AppError.validationError(let validation) = error else {
                return XCTFail("Expected validation error, got \(error)")
            }
            XCTAssertTrue(validation.message.contains("already locked"))
        }
    }

    func testLockedAmountsCaptionMatchesTicketCopy() {
        XCTAssertEqual(
            OpeningSplitService.lockedAmountsCaption,
            "Locked amounts never change"
        )
    }

    func testAllocatePaisaSumsExactlyForAwkwardFractions() {
        let amounts = OpeningSplitService.allocatePaisa(
            total: 100,
            fractions: [
                Decimal(string: "0.3333")!,
                Decimal(string: "0.3333")!,
                Decimal(string: "0.3334")!
            ]
        )
        XCTAssertEqual(amounts.reduce(0, +), 100)
    }

    // MARK: - Helpers

    private func sampleGoals() -> [Goal] {
        [
            Goal(
                id: carID,
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
                id: emergencyID,
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
