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
