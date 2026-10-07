import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class ModelSerializationTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testAccountRoundTrip() throws {
        let original = Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: false
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Account.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testGoalRoundTripPreservesStoredFields() throws {
        let start = ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")!
        let created = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        let updated = ISO8601DateFormatter().date(from: "2026-01-02T12:00:00Z")!

        let original = Goal(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Car",
            targetAmount: 50_000_000,
            startDate: start,
            endDate: end,
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: 12_000_000,
            shareOfNewCredits: Decimal(string: "0.6")!,
            createdAt: created,
            updatedAt: updated
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Goal.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.targetAmount, original.targetAmount)
        XCTAssertEqual(decoded.startDate, original.startDate)
        XCTAssertEqual(decoded.endDate, original.endDate)
        XCTAssertEqual(decoded.inflationRate, original.inflationRate)
        XCTAssertEqual(decoded.savedAmount, original.savedAmount)
        XCTAssertEqual(decoded.shareOfNewCredits, original.shareOfNewCredits)
        XCTAssertEqual(decoded.createdAt, original.createdAt)
        XCTAssertEqual(decoded.updatedAt, original.updatedAt)
    }

    func testHistoryEntryRoundTripWithAllocations() throws {
        let created = ISO8601DateFormatter().date(from: "2026-03-01T10:00:00Z")!
        let goalID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let original = HistoryEntry(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            type: .newCredit,
            createdAt: created,
            isLocked: true,
            previousBalance: 10_000_000,
            newBalance: 11_000_000,
            creditAmount: 1_000_000,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: [
                GoalAllocation(
                    goalId: goalID,
                    goalName: "Car",
                    amount: 600_000,
                    percentage: Decimal(string: "0.6")!
                ),
                GoalAllocation(
                    goalId: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    goalName: "Emergency Fund",
                    amount: 400_000,
                    percentage: Decimal(string: "0.4")!
                )
            ]
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HistoryEntry.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testStandingSplitRoundTrip() throws {
        let original = StandingSplit(
            goalId: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            percentage: Decimal(string: "0.4")!
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(StandingSplit.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testHistoryEntryTypeCasesMatchContract() {
        let cases = HistoryEntryType.allCases.map(\.rawValue)
        XCTAssertEqual(
            cases,
            ["openingBalance", "newCredit", "transfer", "withdrawal", "goalDeleted"]
        )
    }

    func testAppStateRoundTrip() throws {
        let state = PersistedAppState(
            accounts: [
                Account(
                    id: UUID(),
                    bankName: "SBI",
                    maskedNumber: "••7730",
                    balance: 7_200_000,
                    isDedicated: false,
                    isPaytmLinked: false,
                    consentAutoUpdate: false
                )
            ],
            goals: [],
            history: [],
            standingSplits: [],
            heldGoalChanges: []
        )

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(PersistedAppState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testHeldGoalChangeRoundTrip() throws {
        let start = ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!
        let end = ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z")!
        let savedAt = ISO8601DateFormatter().date(from: "2026-03-01T12:00:00Z")!
        let original = HeldGoalChange(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            goalId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            savedAt: savedAt,
            previousName: "Car",
            pendingName: "SUV",
            previousTargetAmount: 50_000_000,
            pendingTargetAmount: 60_000_000,
            previousShareOfNewCredits: Decimal(string: "0.6")!,
            pendingShareOfNewCredits: Decimal(string: "0.55")!,
            previousInflationRate: Decimal(string: "0.07")!,
            pendingInflationRate: Decimal(string: "0.08")!,
            previousStartDate: start,
            pendingStartDate: start,
            previousEndDate: end,
            pendingEndDate: end
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HeldGoalChange.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAppStateDecodesWhenHeldGoalChangesKeyMissing() throws {
        let json = """
        {
          "accounts": [],
          "goals": [],
          "history": [],
          "standingSplits": []
        }
        """
        let decoded = try decoder.decode(PersistedAppState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.heldGoalChanges, [])
    }
}
