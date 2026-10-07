import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class SettingsServiceTests: XCTestCase {
    func testApplyingConsentUpdatesOnlyDedicatedAccount() {
        let accounts = [
            makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: false),
            makeAccount(id: "22222222-2222-2222-2222-222222222222", dedicated: false, consent: false)
        ]
        let updated = SettingsService.applyingConsent(autoUpdate: true, to: accounts)
        XCTAssertTrue(updated[0].consentAutoUpdate)
        XCTAssertFalse(updated[1].consentAutoUpdate)
        XCTAssertEqual(SettingsService.consentAutoUpdate(in: updated), true)
    }

    func testConsentOffDrivesUpdateBalanceOnGoals() {
        let accounts = [
            makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: false)
        ]
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: accounts), .updateBalance)
        XCTAssertEqual(
            GoalsTabService.balanceActionTitle(for: .updateBalance),
            "Update balance"
        )
    }

    func testConsentOnDrivesSyncOnGoals() {
        let accounts = [
            makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: true)
        ]
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: accounts), .sync)
        XCTAssertEqual(GoalsTabService.balanceActionTitle(for: .sync), "Sync")
    }

    func testTurningOnWhileOffShouldReopenConsent() {
        XCTAssertTrue(SettingsService.shouldReopenConsent(currentAutoUpdate: false, turningOn: true))
        XCTAssertFalse(SettingsService.shouldReopenConsent(currentAutoUpdate: true, turningOn: false))
        XCTAssertFalse(SettingsService.shouldReopenConsent(currentAutoUpdate: true, turningOn: true))
        XCTAssertFalse(SettingsService.shouldReopenConsent(currentAutoUpdate: false, turningOn: false))
    }

    func testLinkedAccountsListsDedicatedFirst() {
        let spending = makeAccount(id: "22222222-2222-2222-2222-222222222222", dedicated: false, consent: false)
        let dedicated = makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: true)
        let linked = SettingsService.linkedAccounts(from: [spending, dedicated])
        XCTAssertEqual(linked.map(\.id), [dedicated.id, spending.id])
        XCTAssertEqual(SettingsService.roleLabel(for: dedicated), "Dedicated savings")
        XCTAssertEqual(SettingsService.roleLabel(for: spending), "Spending")
        XCTAssertEqual(SettingsService.linkSubtitle(for: dedicated), "Linked in Paytm")
    }

    func testUntypedGapHintCopyPresentWhileOff() {
        XCTAssertFalse(SettingsService.untypedGapWhileOffHint.isEmpty)
        XCTAssertTrue(SettingsService.untypedGapWhileOffHint.lowercased().contains("one amount"))
    }

    func testConsentPersistenceRoundTripViaPersistenceService() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsService-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceService(storageDirectory: directory)
        let seeded = PersistedAppState(
            accounts: [
                makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: false),
                makeAccount(id: "22222222-2222-2222-2222-222222222222", dedicated: false, consent: false)
            ],
            goals: [],
            history: [],
            standingSplits: []
        )
        try await persistence.saveState(seeded)

        var state = try await persistence.loadState()
        state.accounts = SettingsService.applyingConsent(autoUpdate: true, to: state.accounts)
        try await persistence.saveState(state)

        let reloaded = try await persistence.loadState()
        XCTAssertTrue(SettingsService.consentAutoUpdate(in: reloaded.accounts))
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: reloaded.accounts), .sync)

        state = reloaded
        state.accounts = SettingsService.applyingConsent(autoUpdate: false, to: state.accounts)
        try await persistence.saveState(state)

        let off = try await persistence.loadState()
        XCTAssertFalse(SettingsService.consentAutoUpdate(in: off.accounts))
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: off.accounts), .updateBalance)
    }

    func testResetDemoClearsGoalsAndHistoryForWelcome() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceService(storageDirectory: directory)
        let goalID = UUID()
        let seeded = PersistedAppState(
            accounts: [
                makeAccount(id: "11111111-1111-1111-1111-111111111111", dedicated: true, consent: true)
            ],
            goals: [
                Goal(
                    id: goalID,
                    name: "Car",
                    targetAmount: 50_000_000,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86_400 * 365),
                    inflationRate: Decimal(string: "0.07")!,
                    savedAmount: 1_000_000,
                    shareOfNewCredits: Decimal(string: "1.0")!,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ],
            history: [
                HistoryEntry(
                    id: UUID(),
                    type: .openingBalance,
                    createdAt: Date(),
                    isLocked: true,
                    previousBalance: nil,
                    newBalance: 10_000_000,
                    creditAmount: 10_000_000,
                    isTyped: false,
                    fromGoalId: nil,
                    toGoalId: nil,
                    transferAmount: nil,
                    withdrawalAmount: nil,
                    deletedGoalName: nil,
                    releasedAmount: nil,
                    allocations: []
                )
            ],
            standingSplits: [
                StandingSplit(goalId: goalID, percentage: Decimal(string: "1.0")!)
            ]
        )
        try await persistence.saveState(seeded)
        XCTAssertEqual(AppLaunchRouter.destination(for: seeded), .goals)

        try await persistence.resetDemo()
        let cleared = try await persistence.loadState()
        XCTAssertTrue(cleared.goals.isEmpty)
        XCTAssertTrue(cleared.history.isEmpty)
        XCTAssertTrue(cleared.accounts.isEmpty)
        XCTAssertTrue(AppLaunchRouter.isFirstRunOrPostReset(cleared))
        XCTAssertEqual(AppLaunchRouter.destination(for: cleared), .welcome)
    }

    private func makeAccount(id: String, dedicated: Bool, consent: Bool) -> Account {
        Account(
            id: UUID(uuidString: id)!,
            bankName: dedicated ? "HDFC" : "SBI",
            maskedNumber: dedicated ? "••4821" : "••7730",
            balance: dedicated ? 10_000_000 : 7_200_000,
            isDedicated: dedicated,
            isPaytmLinked: true,
            consentAutoUpdate: consent
        )
    }
}
