import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class HistoryServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let formatting = FormattingService()

    // MARK: - Newest first

    func testSortedNewestFirst() {
        let older = makeEntry(id: UUID(), type: .openingBalance, locked: true, createdAt: Date(timeIntervalSince1970: 100))
        let newer = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date(timeIntervalSince1970: 200))
        let newest = makeEntry(id: UUID(), type: .transfer, locked: true, createdAt: Date(timeIntervalSince1970: 300))

        let sorted = HistoryService.sortedNewestFirst([older, newest, newer])
        XCTAssertEqual(sorted.map(\.id), [newest.id, newer.id, older.id])
    }

    // MARK: - Labels / icons

    func testTypeLabelsDistinguishAllKinds() {
        XCTAssertEqual(HistoryService.typeLabel(for: .openingBalance), "Opening balance")
        XCTAssertEqual(HistoryService.typeLabel(for: .newCredit), "New credit")
        XCTAssertEqual(HistoryService.typeLabel(for: .transfer), "Transfer")
        XCTAssertEqual(HistoryService.typeLabel(for: .withdrawal), "Withdrawal")
        XCTAssertEqual(HistoryService.typeLabel(for: .goalDeleted), "Goal deleted")
    }

    func testSystemImageNamesAreDistinct() {
        let images = HistoryEntryType.allCases.map(HistoryService.systemImageName(for:))
        XCTAssertEqual(Set(images).count, HistoryEntryType.allCases.count)
    }

    // MARK: - Open vs locked / read-only

    func testOpenAssignNowCreditIsEditable() {
        let open = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date())
        XCTAssertTrue(HistoryService.canEditAsCredit(open))
        XCTAssertFalse(HistoryService.isReadOnly(open))
        XCTAssertFalse(HistoryService.showsLockIcon(open))
        XCTAssertEqual(HistoryService.destination(for: open), .editableCredit)
        XCTAssertEqual(HistoryService.rowSubtitle(for: open), "Assign now")
    }

    func testLockedCreditIsReadOnlyWithOriginalCaption() {
        let locked = makeEntry(id: UUID(), type: .newCredit, locked: true, createdAt: Date())
        XCTAssertFalse(HistoryService.canEditAsCredit(locked))
        XCTAssertTrue(HistoryService.isReadOnly(locked))
        XCTAssertTrue(HistoryService.showsLockIcon(locked))
        XCTAssertEqual(HistoryService.destination(for: locked), .readOnlyDetail)
        XCTAssertEqual(HistoryService.originalAmountsCaption, "Original amounts never change")
    }

    func testOpeningBalanceAlwaysReadOnlyEvenIfUnlockedFlag() {
        var opening = makeEntry(id: UUID(), type: .openingBalance, locked: false, createdAt: Date())
        XCTAssertTrue(HistoryService.isReadOnly(opening))
        XCTAssertEqual(HistoryService.destination(for: opening), .readOnlyDetail)
        XCTAssertFalse(HistoryService.canEditAsCredit(opening))

        opening.isLocked = true
        XCTAssertTrue(HistoryService.isReadOnly(opening))
        XCTAssertTrue(HistoryService.showsLockIcon(opening))
    }

    func testTransferAndWithdrawalAndDeletionAreLockedReadOnly() {
        let transfer = makeEntry(id: UUID(), type: .transfer, locked: true, createdAt: Date())
        let withdrawal = makeEntry(id: UUID(), type: .withdrawal, locked: true, createdAt: Date())
        let deleted = makeEntry(id: UUID(), type: .goalDeleted, locked: true, createdAt: Date())

        for entry in [transfer, withdrawal, deleted] {
            XCTAssertTrue(HistoryService.isReadOnly(entry))
            XCTAssertTrue(HistoryService.showsLockIcon(entry))
            XCTAssertEqual(HistoryService.destination(for: entry), .readOnlyDetail)
            XCTAssertFalse(HistoryService.canEditAsCredit(entry))
        }
    }

    // MARK: - Amounts / transfer subtitle

    func testPrimaryAmountByType() {
        var credit = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date())
        credit.creditAmount = 1_000_000
        XCTAssertEqual(HistoryService.primaryAmountPaisa(for: credit), 1_000_000)

        var transfer = makeEntry(id: UUID(), type: .transfer, locked: true, createdAt: Date())
        transfer.transferAmount = 500_000
        transfer.fromGoalId = carID
        transfer.toGoalId = emergencyID
        XCTAssertEqual(HistoryService.primaryAmountPaisa(for: transfer), 500_000)

        var withdrawal = makeEntry(id: UUID(), type: .withdrawal, locked: true, createdAt: Date())
        withdrawal.withdrawalAmount = 250_000
        XCTAssertEqual(HistoryService.primaryAmountPaisa(for: withdrawal), 250_000)

        var deleted = makeEntry(id: UUID(), type: .goalDeleted, locked: true, createdAt: Date())
        deleted.releasedAmount = 6_000_000
        deleted.deletedGoalName = "Car"
        XCTAssertEqual(HistoryService.primaryAmountPaisa(for: deleted), 6_000_000)
    }

    func testTransferRowSubtitleUsesFromToAmount() {
        var transfer = makeEntry(id: UUID(), type: .transfer, locked: true, createdAt: Date())
        transfer.transferAmount = 500_000
        transfer.fromGoalId = carID
        transfer.toGoalId = emergencyID
        transfer.allocations = [
            GoalAllocation(goalId: carID, goalName: "Car", amount: 500_000, percentage: 1),
            GoalAllocation(goalId: emergencyID, goalName: "Emergency Fund", amount: 500_000, percentage: 1)
        ]

        let goals = [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: Date(),
                endDate: Date(),
                inflationRate: 0,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: Date(),
                endDate: Date(),
                inflationRate: 0,
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let subtitle = HistoryService.rowSubtitle(for: transfer, goals: goals, formatting: formatting)
        XCTAssertEqual(
            subtitle,
            TransferService.historyTitle(
                fromName: "Car",
                toName: "Emergency Fund",
                amountPaisa: 500_000,
                formatting: formatting
            )
        )
    }

    func testEmptyStateMessage() {
        XCTAssertFalse(HistoryService.emptyStateMessage.isEmpty)
        XCTAssertTrue(HistoryService.emptyStateMessage.lowercased().contains("history"))
    }

    // MARK: - PIP-104 list labels / open vs saved

    func testListTypeLabelDistinguishesTypedAndCustomSplit() {
        let open = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date())
        XCTAssertEqual(HistoryService.listTypeLabel(for: open), "New credit")

        var typed = makeEntry(id: UUID(), type: .newCredit, locked: true, createdAt: Date())
        typed.isTyped = true
        XCTAssertEqual(HistoryService.listTypeLabel(for: typed), "Typed")
        XCTAssertEqual(HistoryService.rowBadges(for: typed), [.typed])
        XCTAssertEqual(HistoryService.rowBadgeTitles(for: typed), [])

        var custom = makeEntry(id: UUID(), type: .newCredit, locked: true, createdAt: Date())
        custom.customSplit = true
        XCTAssertEqual(HistoryService.listTypeLabel(for: custom), "Custom split")
        XCTAssertEqual(HistoryService.rowBadgeTitles(for: custom), [])

        var typedCustom = makeEntry(id: UUID(), type: .newCredit, locked: true, createdAt: Date())
        typedCustom.isTyped = true
        typedCustom.customSplit = true
        XCTAssertEqual(HistoryService.listTypeLabel(for: typedCustom), "Custom split")
        XCTAssertEqual(HistoryService.rowBadgeTitles(for: typedCustom), ["Typed"])
    }

    func testSavedEntriesExcludesOpenAssignNowCredit() {
        let opening = makeEntry(id: UUID(), type: .openingBalance, locked: true, createdAt: Date(timeIntervalSince1970: 100))
        let open = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date(timeIntervalSince1970: 200))
        let locked = makeEntry(id: UUID(), type: .newCredit, locked: true, createdAt: Date(timeIntervalSince1970: 300))

        let saved = HistoryService.savedEntries(in: [opening, open, locked])
        XCTAssertEqual(saved.map(\.id), [locked.id, opening.id])
        XCTAssertEqual(HistoryService.openCreditEntry(in: [opening, open, locked])?.id, open.id)
        XCTAssertEqual(HistoryService.destination(for: open), .editableCredit)
        XCTAssertEqual(HistoryService.destination(for: locked), .readOnlyDetail)
        XCTAssertEqual(HistoryService.destination(for: opening), .readOnlyDetail)
    }

    func testOpenCreditDiscoveryMatchesLedgerEngine() {
        let ledger: any LedgerEngine = StubLedgerEngine()
        let open = makeEntry(id: UUID(), type: .newCredit, locked: false, createdAt: Date())
        let locked = makeEntry(id: UUID(), type: .transfer, locked: true, createdAt: Date())
        let history = [locked, open]
        XCTAssertEqual(HistoryService.openCreditEntry(in: history)?.id, open.id)
        XCTAssertEqual(ledger.openCreditEntry(in: history)?.id, open.id)
    }

    // MARK: - Helpers

    private func makeEntry(
        id: UUID,
        type: HistoryEntryType,
        locked: Bool,
        createdAt: Date
    ) -> HistoryEntry {
        HistoryEntry(
            id: id,
            type: type,
            createdAt: createdAt,
            isLocked: locked,
            previousBalance: nil,
            newBalance: type == .openingBalance ? 10_000_000 : nil,
            creditAmount: type == .openingBalance || type == .newCredit ? 10_000_000 : nil,
            isTyped: type == .newCredit ? false : nil,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: []
        )
    }
}
