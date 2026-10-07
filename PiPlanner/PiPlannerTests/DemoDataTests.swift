import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class DemoDataTests: XCTestCase {
    func testPersonaNameIsRahul() {
        XCTAssertEqual(DemoData.personaName, "Rahul")
        XCTAssertEqual(DemoSeed.personaName, "Rahul")
    }

    func testSampleAccountsMatchHDFCAndSBIPersona() {
        let accounts = DemoData.sampleAccounts
        XCTAssertEqual(accounts.count, 2)

        let hdfc = accounts[0]
        XCTAssertEqual(hdfc.id, DemoData.hdfcAccountID)
        XCTAssertEqual(hdfc.bankName, "HDFC")
        XCTAssertEqual(hdfc.maskedNumber, "••4821")
        XCTAssertEqual(hdfc.balance, 10_000_000)
        XCTAssertFalse(hdfc.isDedicated)
        XCTAssertTrue(hdfc.isPaytmLinked)

        let sbi = accounts[1]
        XCTAssertEqual(sbi.id, DemoData.sbiAccountID)
        XCTAssertEqual(sbi.bankName, "SBI")
        XCTAssertEqual(sbi.maskedNumber, "••7730")
        XCTAssertEqual(sbi.balance, 7_200_000)
        XCTAssertFalse(sbi.isDedicated)
        XCTAssertTrue(sbi.isPaytmLinked)
    }

    func testPostSetupAccountsMarkHDFCDedicatedAndSBISpending() {
        let accounts = DemoData.postSetupAccounts(consentAutoUpdate: true)
        XCTAssertTrue(accounts[0].isDedicated)
        XCTAssertTrue(accounts[0].consentAutoUpdate)
        XCTAssertEqual(accounts[0].balance, DemoData.openingBalancePaisa)
        XCTAssertFalse(accounts[1].isDedicated)
        XCTAssertEqual(accounts[1].balance, DemoData.spendingBalancePaisa)
        XCTAssertEqual(AccountsService.dedicatedAccount(in: accounts)?.bankName, "HDFC")
    }

    func testPostSetupStateSeedsHappyPathGoalsAndOpening() {
        let state = DemoData.postSetupState(consentAutoUpdate: true)
        XCTAssertEqual(state.goals.map(\.name), ["Car", "Emergency Fund"])
        XCTAssertEqual(state.goals[0].shareOfNewCredits, Decimal(string: "0.6")!)
        XCTAssertEqual(state.goals[1].shareOfNewCredits, Decimal(string: "0.4")!)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history[0].type, .openingBalance)
        XCTAssertTrue(state.history[0].isLocked)
        XCTAssertEqual(state.history[0].creditAmount, DemoData.openingBalancePaisa)
        XCTAssertEqual(AppLaunchRouter.destination(for: state), .goals)
    }

    func testGreetingAdjustsForTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(hour: Int) -> Date {
            var components = DateComponents()
            components.year = 2026
            components.month = 10
            components.day = 7
            components.hour = hour
            return calendar.date(from: components)!
        }

        XCTAssertEqual(DemoData.greeting(at: date(hour: 8), calendar: calendar), "Good morning, Rahul")
        XCTAssertEqual(DemoData.greeting(at: date(hour: 14), calendar: calendar), "Good afternoon, Rahul")
        XCTAssertEqual(DemoData.greeting(at: date(hour: 19), calendar: calendar), "Good evening, Rahul")
        XCTAssertEqual(DemoData.greeting(at: date(hour: 23), calendar: calendar), "Good evening, Rahul")
        XCTAssertTrue(DemoData.greeting(at: date(hour: 19), calendar: calendar).contains("Rahul"))
    }

    func testSpendingAccountPaymentsProduceNoHistory() {
        let spending = DemoData.sampleAccounts[1]
        XCTAssertFalse(DemoData.tracksPayments(on: spending))
        let entries = DemoData.historyEntriesForSpendingPayment(on: spending, amountPaisa: 50_000)
        XCTAssertTrue(entries.isEmpty, "R25: PiPlanner shows nothing for SBI spending payments")

        let dedicated = DemoData.postSetupAccounts(consentAutoUpdate: true)[0]
        XCTAssertTrue(DemoData.tracksPayments(on: dedicated))
        // Dedicated credits are handled by Credit/Opening flows — helper still returns [].
        XCTAssertTrue(DemoData.historyEntriesForSpendingPayment(on: dedicated).isEmpty)
    }

    func testFirstLaunchAndPostResetUseSameSeedAccounts() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoData-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceService(storageDirectory: directory)

        // First launch — empty file → seed sample accounts in memory path.
        let first = try await persistence.loadState()
        XCTAssertTrue(first.accounts.isEmpty)
        XCTAssertEqual(AppLaunchRouter.destination(for: first), .welcome)
        let seeded = first.accounts.isEmpty ? DemoData.sampleAccounts : first.accounts
        XCTAssertEqual(seeded.map(\.bankName), ["HDFC", "SBI"])

        try await persistence.saveState(DemoData.postSetupState(consentAutoUpdate: true))
        try await persistence.resetDemo()
        let afterReset = try await persistence.loadState()
        XCTAssertTrue(afterReset.accounts.isEmpty)
        XCTAssertTrue(AppLaunchRouter.isFirstRunOrPostReset(afterReset))
        XCTAssertEqual(
            (afterReset.accounts.isEmpty ? DemoData.sampleAccounts : afterReset.accounts).map(\.maskedNumber),
            ["••4821", "••7730"]
        )
    }

    func testHappyPathGrokProposalsMatchDemoGoals() {
        let proposals = StubGrokService.happyPathProposals
        XCTAssertEqual(proposals.map(\.name), ["Car", "Emergency Fund"])
        XCTAssertEqual(proposals[0].id, DemoData.carGoalID)
        XCTAssertEqual(proposals[1].id, DemoData.emergencyGoalID)
        XCTAssertEqual(proposals.map(\.sharePercentage), [
            Decimal(string: "0.6")!,
            Decimal(string: "0.4")!
        ])
    }
}
