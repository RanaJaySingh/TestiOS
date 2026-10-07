import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class GoalsTabServiceTests: XCTestCase {
    private let formatting = FormattingService()

    // MARK: - Tab layout contract

    func testTabBarTitlesAreGoalsHistoryAsk() {
        XCTAssertEqual(GoalsTabService.tabTitles, ["Goals", "History", "Ask"])
        XCTAssertFalse(GoalsTabService.tabTitles.contains("Settings"))
    }

    // MARK: - Total savings / INR

    func testTotalSavingsPrefersDedicatedAccountBalance() {
        let accounts = [
            Account(
                id: UUID(),
                bankName: "HDFC",
                maskedNumber: "••4821",
                balance: 10_000_000,
                isDedicated: true,
                isPaytmLinked: true,
                consentAutoUpdate: true
            )
        ]
        let goals = [
            makeGoal(name: "Car", saved: 6_000_000),
            makeGoal(name: "Emergency", saved: 4_000_000)
        ]
        let total = GoalsTabService.totalSavingsPaisa(accounts: accounts, goals: goals)
        XCTAssertEqual(total, 10_000_000)
        XCTAssertEqual(formatting.formatINR(paisa: total), "₹1,00,000")
    }

    func testTotalSavingsFallsBackToSumOfGoalSavedAmounts() {
        let goals = [
            makeGoal(name: "Car", saved: 6_000_000),
            makeGoal(name: "Emergency", saved: 4_000_000)
        ]
        let total = GoalsTabService.totalSavingsPaisa(accounts: [], goals: goals)
        XCTAssertEqual(total, 10_000_000)
        XCTAssertEqual(formatting.formatINR(paisa: total), "₹1,00,000")
    }

    // MARK: - Consent → CTA

    func testConsentOnShowsSyncAction() {
        let accounts = [dedicated(consent: true)]
        XCTAssertEqual(GoalsTabService.balanceAction(for: accounts), .sync)
        XCTAssertEqual(GoalsTabService.balanceActionTitle(for: .sync), "Sync")
    }

    func testConsentOffShowsUpdateBalanceAction() {
        let accounts = [dedicated(consent: false)]
        XCTAssertEqual(GoalsTabService.balanceAction(for: accounts), .updateBalance)
        XCTAssertEqual(
            GoalsTabService.balanceActionTitle(for: .updateBalance),
            "Update balance"
        )
    }

    func testMissingDedicatedDefaultsToUpdateBalance() {
        XCTAssertEqual(GoalsTabService.balanceAction(for: []), .updateBalance)
    }

    // MARK: - Goal card status / presence

    func testStatusLabelsMatchDesignCopy() {
        XCTAssertEqual(GoalsTabService.statusLabel(for: .onTrack), "On track")
        XCTAssertEqual(
            GoalsTabService.statusLabel(for: .behind(shortfall: 100)),
            "Behind"
        )
    }

    func testHasGoalsDetectsPostSetupWithGoals() {
        XCTAssertFalse(GoalsTabService.hasGoals([]))
        XCTAssertTrue(GoalsTabService.hasGoals([makeGoal(name: "Car", saved: 0)]))
    }

    func testDedicatedAccountSubtitle() {
        let accounts = [dedicated(consent: true)]
        XCTAssertEqual(
            GoalsTabService.dedicatedAccountSubtitle(accounts: accounts),
            "HDFC ••4821"
        )
        XCTAssertNil(GoalsTabService.dedicatedAccountSubtitle(accounts: []))
    }

    // MARK: - PIP-81 presentation helpers (visual labels only)

    func testQuickBalanceActionTitleSyncVsUpdate() {
        XCTAssertEqual(GoalsTabService.quickBalanceActionTitle(for: .sync), "Sync")
        XCTAssertEqual(GoalsTabService.quickBalanceActionTitle(for: .updateBalance), "Update")
        XCTAssertEqual(GoalsTabService.balanceActionTitle(for: .updateBalance), "Update balance")
    }

    func testLastBalanceActivityLineConsentOnUsesSynced() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let line = GoalsTabService.lastBalanceActivityLine(
            for: .sync,
            referenceDate: now,
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(line.hasPrefix("Last synced today,"), line)
    }

    func testLastBalanceActivityLineConsentOffUsesUpdated() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let line = GoalsTabService.lastBalanceActivityLine(
            for: .updateBalance,
            referenceDate: now,
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(line.hasPrefix("Last updated today,"), line)
    }

    func testLastBalanceActivityDateUsesNewestHistory() {
        let older = HistoryEntry(
            id: UUID(),
            type: .openingBalance,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
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
        let newer = HistoryEntry(
            id: UUID(),
            type: .newCredit,
            createdAt: Date(timeIntervalSince1970: 1_700_086_400),
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
            allocations: []
        )
        XCTAssertEqual(
            GoalsTabService.lastBalanceActivityDate(history: [older, newer]),
            newer.createdAt
        )
        XCTAssertNil(GoalsTabService.lastBalanceActivityDate(history: []))
    }

    func testGoalCardPresentationLabels() {
        XCTAssertEqual(
            GoalsTabService.savedOfTargetLabel(
                savedPaisa: 6_000_000,
                targetPaisa: 131_079_600,
                formatting: formatting
            ),
            "₹60,000 of ₹13,10,796"
        )
        XCTAssertEqual(
            GoalsTabService.monthlyNeedLabel(monthlyNeedPaisa: 2_605_800, formatting: formatting),
            "Needs ₹26,058 a month"
        )
        XCTAssertEqual(
            GoalsTabService.creditsPercentLabel(shareOfNewCredits: Decimal(string: "0.6")!),
            "60% of credits"
        )
    }

    // MARK: - Helpers

    private func dedicated(consent: Bool) -> Account {
        Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            bankName: "HDFC",
            maskedNumber: "••4821",
            balance: 10_000_000,
            isDedicated: true,
            isPaytmLinked: true,
            consentAutoUpdate: consent
        )
    }

    private func makeGoal(name: String, saved: Paisa) -> Goal {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400 * 365)
        return Goal(
            id: UUID(),
            name: name,
            targetAmount: 50_000_000,
            startDate: start,
            endDate: end,
            inflationRate: Decimal(string: "0.07")!,
            savedAmount: saved,
            shareOfNewCredits: Decimal(string: "0.5")!,
            createdAt: start,
            updatedAt: start
        )
    }
}
