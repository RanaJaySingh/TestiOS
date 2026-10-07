import Foundation

/// Demo persona seed — Spec §4.2 `Resources/DemoData.swift` / PRD §3 · PIP-65.
/// Lives under Services so Linux `swift test` (PiPlannerCore) can assert seeding.
enum DemoData {
    /// Fixed demo persona (PRD A8).
    static let personaName = "Rahul"

    /// HDFC dedicated opening balance — ₹1,00,000 (paisa).
    static let openingBalancePaisa: Paisa = 10_000_000
    /// SBI spending balance — ₹72,000 (paisa); not tracked for credits (R25).
    static let spendingBalancePaisa: Paisa = 7_200_000

    static let hdfcAccountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let sbiAccountID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let carGoalID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let emergencyGoalID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let openingHistoryID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    // MARK: - Greeting (PRD A8)

    /// Time-of-day greeting with persona name, e.g. "Good evening, Rahul".
    static func greeting(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let period: String
        switch hour {
        case 5..<12:
            period = "morning"
        case 12..<17:
            period = "afternoon"
        default:
            period = "evening"
        }
        return "Good \(period), \(personaName)"
    }

    // MARK: - Accounts (first launch / post–Reset)

    /// Seeded Paytm-linked accounts before dedicated selection (frame 2).
    /// HDFC savings ₹1,00,000; SBI spending ₹72,000 — neither dedicated yet.
    static var sampleAccounts: [Account] {
        [
            Account(
                id: hdfcAccountID,
                bankName: "HDFC",
                maskedNumber: "••4821",
                balance: openingBalancePaisa,
                isDedicated: false,
                isPaytmLinked: true,
                consentAutoUpdate: false
            ),
            Account(
                id: sbiAccountID,
                bankName: "SBI",
                maskedNumber: "••7730",
                balance: spendingBalancePaisa,
                isDedicated: false,
                isPaytmLinked: true,
                consentAutoUpdate: false
            )
        ]
    }

    /// Accounts after setup: HDFC dedicated savings; SBI remains spending (R21 / R25).
    static func postSetupAccounts(consentAutoUpdate: Bool) -> [Account] {
        var accounts = sampleAccounts
        accounts[0].isDedicated = true
        accounts[0].consentAutoUpdate = consentAutoUpdate
        accounts[0].balance = openingBalancePaisa
        accounts[1].isDedicated = false
        accounts[1].balance = spendingBalancePaisa
        return accounts
    }

    // MARK: - R25 Spending payments not seen

    /// Only the dedicated savings account’s activity is tracked (PRD R21 / R25).
    static func tracksPayments(on account: Account) -> Bool {
        account.isDedicated
    }

    /// Spending-account payments produce no History and are not interrupted (R25).
    /// Always returns an empty list — PiPlanner shows nothing for those payments.
    static func historyEntriesForSpendingPayment(
        on account: Account,
        amountPaisa _: Paisa = 0
    ) -> [HistoryEntry] {
        guard !tracksPayments(on: account) else {
            // Dedicated credits are recorded via Credit / Opening flows — not here.
            return []
        }
        return []
    }

    // MARK: - Goals (happy-path Car / Emergency Fund)

    static var sampleGoals: [Goal] {
        let start = Date()
        let end = start.addingTimeInterval(86_400 * 365)
        return [
            Goal(
                id: carGoalID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: start,
                endDate: end,
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: start,
                updatedAt: start
            ),
            Goal(
                id: emergencyGoalID,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: start,
                endDate: end,
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: start,
                updatedAt: start
            )
        ]
    }

    /// Completed setup snapshot for UI tests / demos (locked Opening balance + goals).
    static func postSetupState(consentAutoUpdate: Bool) -> PersistedAppState {
        let accounts = postSetupAccounts(consentAutoUpdate: consentAutoUpdate)

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var goals = sampleGoals
        goals[0].savedAmount = 6_000_000
        goals[0].startDate = start
        goals[0].endDate = start.addingTimeInterval(86_400 * 365)
        goals[0].createdAt = start
        goals[0].updatedAt = start
        goals[1].savedAmount = 4_000_000
        goals[1].startDate = start
        goals[1].endDate = start.addingTimeInterval(86_400 * 365)
        goals[1].createdAt = start
        goals[1].updatedAt = start

        let opening = HistoryEntry(
            id: openingHistoryID,
            type: .openingBalance,
            createdAt: start,
            isLocked: true,
            previousBalance: nil,
            newBalance: openingBalancePaisa,
            creditAmount: openingBalancePaisa,
            isTyped: false,
            fromGoalId: nil,
            toGoalId: nil,
            transferAmount: nil,
            withdrawalAmount: nil,
            deletedGoalName: nil,
            releasedAmount: nil,
            allocations: [
                GoalAllocation(
                    goalId: goals[0].id,
                    goalName: goals[0].name,
                    amount: 6_000_000,
                    percentage: Decimal(string: "0.6")!
                ),
                GoalAllocation(
                    goalId: goals[1].id,
                    goalName: goals[1].name,
                    amount: 4_000_000,
                    percentage: Decimal(string: "0.4")!
                )
            ]
        )

        return PersistedAppState(
            accounts: accounts,
            goals: goals,
            history: [opening],
            standingSplits: [
                StandingSplit(goalId: goals[0].id, percentage: Decimal(string: "0.6")!),
                StandingSplit(goalId: goals[1].id, percentage: Decimal(string: "0.4")!)
            ]
        )
    }
}

/// Compatibility alias — existing Views / previews / Settings reset use `DemoSeed`.
typealias DemoSeed = DemoData
