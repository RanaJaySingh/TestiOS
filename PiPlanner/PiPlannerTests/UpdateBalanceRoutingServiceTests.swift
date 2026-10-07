import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class UpdateBalanceRoutingServiceTests: XCTestCase {
    private let goalA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let goalB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let entryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_100)

    // MARK: - Consent No routes

    func testManuallyRoutesToManualAmount() {
        XCTAssertEqual(
            UpdateBalanceRoutingService.route(after: .manually, dedicatedIsPaytmLinked: true),
            .manualAmount
        )
        XCTAssertEqual(
            UpdateBalanceRoutingService.route(after: .manually, dedicatedIsPaytmLinked: false),
            .manualAmount
        )
    }

    func testBalanceSyncPaytmLinkedRoutesToUPIPinMock() {
        XCTAssertEqual(
            UpdateBalanceRoutingService.route(after: .balanceSync, dedicatedIsPaytmLinked: true),
            .upiPinMock
        )
    }

    func testBalanceSyncOtherUPIAppRoutesToOtherAppOnly() {
        XCTAssertEqual(
            UpdateBalanceRoutingService.route(after: .balanceSync, dedicatedIsPaytmLinked: false),
            .otherUPIApp
        )
        XCTAssertEqual(
            UpdateBalanceRoutingService.routeAfterOtherUPIApp(),
            .manualAmount
        )
    }

    func testWrongPinRetryAndManual() {
        XCTAssertEqual(
            UpdateBalanceRoutingService.routeAfterWrongPin(retry: true),
            .upiPinMock
        )
        XCTAssertEqual(
            UpdateBalanceRoutingService.routeAfterWrongPin(retry: false),
            .manualAmount
        )
    }

    func testPINSuccessRoutesToFetchedBalance() {
        XCTAssertEqual(
            UpdateBalanceRoutingService.routeAfterPINSuccess(),
            .fetchedBalance
        )
    }

    func testIsTypedFlagByRoute() {
        XCTAssertTrue(UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .manualAmount))
        XCTAssertTrue(UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .otherUPIApp))
        XCTAssertFalse(UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .upiPinMock))
        XCTAssertFalse(UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .fetchedBalance))
    }

    // MARK: - Same History entry shape (Manual vs PIN)

    func testManualAndPINOpenCreditsShareHistoryShape() throws {
        let goals = sampleGoals()
        let standing = [
            StandingSplit(goalId: goalA, percentage: Decimal(string: "0.60")!),
            StandingSplit(goalId: goalB, percentage: Decimal(string: "0.40")!)
        ]

        let manual = try UpdateBalanceRoutingService.makeOpenCreditEntry(
            goals: goals,
            standingSplits: standing,
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            isTyped: true,
            id: entryID,
            createdAt: createdAt
        )
        let pin = try UpdateBalanceRoutingService.makeOpenCreditEntry(
            goals: goals,
            standingSplits: standing,
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            isTyped: false,
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            createdAt: createdAt
        )

        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(manual))
        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(pin))
        XCTAssertEqual(manual.type, pin.type)
        XCTAssertEqual(manual.previousBalance, pin.previousBalance)
        XCTAssertEqual(manual.newBalance, pin.newBalance)
        XCTAssertEqual(manual.creditAmount, pin.creditAmount)
        XCTAssertEqual(manual.allocations.count, pin.allocations.count)
        XCTAssertEqual(manual.isTyped, true)
        XCTAssertEqual(pin.isTyped, false)
    }

    func testManualAndPINOpeningBalancesShareHistoryShape() throws {
        let goals = sampleGoals()
        let percentages: [UUID: Decimal] = [
            goalA: Decimal(string: "0.60")!,
            goalB: Decimal(string: "0.40")!
        ]

        let manual = try UpdateBalanceRoutingService.makeOpeningHistoryEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: percentages,
            isTyped: true,
            id: entryID,
            createdAt: createdAt
        )
        let pin = try UpdateBalanceRoutingService.makeOpeningHistoryEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: percentages,
            isTyped: false,
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            createdAt: createdAt
        )

        XCTAssertTrue(UpdateBalanceRoutingService.assertOpeningBalanceShape(manual))
        XCTAssertTrue(UpdateBalanceRoutingService.assertOpeningBalanceShape(pin))
        XCTAssertEqual(manual.type, pin.type)
        XCTAssertEqual(manual.newBalance, pin.newBalance)
        XCTAssertEqual(manual.creditAmount, pin.creditAmount)
        XCTAssertEqual(manual.allocations.map(\.amount), pin.allocations.map(\.amount))
        XCTAssertEqual(manual.isTyped, true)
        XCTAssertEqual(pin.isTyped, false)
    }

    func testProcessFetchedBalanceManualAndPINSameShape() throws {
        let state = samplePostSetupState()
        let manual = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_500_000,
            dedicatedAccountID: state.accounts.first(where: \.isDedicated)!.id,
            isTyped: true,
            id: entryID,
            createdAt: createdAt
        )
        let pin = try CreditEntryService.processFetchedBalance(
            state: state,
            fetchedBalance: 11_500_000,
            dedicatedAccountID: state.accounts.first(where: \.isDedicated)!.id,
            isTyped: false,
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            createdAt: createdAt
        )

        guard case .openCreditCreated(_, let manualEntry) = manual else {
            return XCTFail("Expected manual open credit")
        }
        guard case .openCreditCreated(_, let pinEntry) = pin else {
            return XCTFail("Expected PIN open credit")
        }
        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(manualEntry))
        XCTAssertTrue(UpdateBalanceRoutingService.assertNewCreditShape(pinEntry))
        XCTAssertEqual(manualEntry.creditAmount, pinEntry.creditAmount)
        XCTAssertNotEqual(manualEntry.isTyped, pinEntry.isTyped)
    }

    // MARK: - Fixtures

    private func sampleGoals() -> [Goal] {
        let now = createdAt
        return [
            Goal(
                id: goalA,
                name: "Emergency",
                targetAmount: 5_000_000,
                startDate: now,
                endDate: now.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.60")!,
                createdAt: now,
                updatedAt: now
            ),
            Goal(
                id: goalB,
                name: "Vacation",
                targetAmount: 3_000_000,
                startDate: now,
                endDate: now.addingTimeInterval(86_400 * 180),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.40")!,
                createdAt: now,
                updatedAt: now
            )
        ]
    }

    private func samplePostSetupState() -> PersistedAppState {
        let goals = sampleGoals()
        let hdfc = Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: false
        )
        let opening = try! OpeningSplitService.createLockedOpeningEntry(
            goals: goals,
            openingBalance: 10_000_000,
            percentages: [
                goalA: Decimal(string: "0.60")!,
                goalB: Decimal(string: "0.40")!
            ],
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            createdAt: createdAt.addingTimeInterval(-3_600),
            isTyped: false
        )
        return PersistedAppState(
            accounts: [hdfc],
            goals: goals,
            history: [opening],
            standingSplits: [
                StandingSplit(goalId: goalA, percentage: Decimal(string: "0.60")!),
                StandingSplit(goalId: goalB, percentage: Decimal(string: "0.40")!)
            ]
        )
    }
}
