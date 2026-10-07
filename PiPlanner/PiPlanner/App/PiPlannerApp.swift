import SwiftUI

@main
struct PiPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Root host. First-run / post–Reset → Welcome (PIP-35); setup complete → Main tabs (PIP-45).
struct ContentView: View {
    @State private var destination: AppLaunchDestination?
    @State private var accountsViewModel: AccountsViewModel?
    @State private var persistence: PersistenceService?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let loadError {
                Text(loadError)
                    .padding()
            } else if let destination, let accountsViewModel, let persistence {
                switch destination {
                case .welcome:
                    WelcomeFlowView(
                        accountsViewModel: accountsViewModel,
                        persistence: persistence
                    )
                case .goals:
                    MainTabView(persistence: persistence)
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            guard destination == nil else { return }
            do {
                let persistence = try PersistenceService.makeDefault()
                if ProcessInfo.processInfo.arguments.contains("-reset-demo") {
                    try await persistence.resetDemo()
                }
                if ProcessInfo.processInfo.arguments.contains("-ui-test-goals") {
                    try await persistence.saveState(DemoSeed.postSetupState(consentAutoUpdate: true))
                }
                let state = try await persistence.loadState()
                destination = AppLaunchRouter.destination(for: state)
                self.persistence = persistence
                accountsViewModel = AccountsViewModel(
                    accounts: state.accounts.isEmpty ? DemoSeed.sampleAccounts : state.accounts,
                    persistence: persistence
                )
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

/// Demo persona seed — Spec persona / PRD demo setup.
enum DemoSeed {
    static let openingBalancePaisa: Paisa = 10_000_000 // ₹1,00,000

    static var sampleAccounts: [Account] {
        [
            Account(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                bankName: "HDFC",
                maskedNumber: "••4821",
                balance: 10_000_000,
                isDedicated: false,
                isPaytmLinked: true,
                consentAutoUpdate: false
            ),
            Account(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                bankName: "SBI",
                maskedNumber: "••7730",
                balance: 7_200_000,
                isDedicated: false,
                isPaytmLinked: true,
                consentAutoUpdate: false
            )
        ]
    }

    static var sampleGoals: [Goal] {
        let start = Date()
        let end = start.addingTimeInterval(86_400 * 365)
        let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        return [
            Goal(
                id: carID,
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
                id: emergencyID,
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
        var accounts = sampleAccounts
        accounts[0].isDedicated = true
        accounts[0].consentAutoUpdate = consentAutoUpdate
        accounts[0].balance = openingBalancePaisa

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
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
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

#Preview {
    ContentView()
}
