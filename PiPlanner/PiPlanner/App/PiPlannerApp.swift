import SwiftUI

@main
struct PiPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Root host. Until Welcome lands, Accounts (frame 2) is reachable for PIP-37 demos.
struct ContentView: View {
    @State private var accountsViewModel: AccountsViewModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let accountsViewModel {
                AccountsFlowView(viewModel: accountsViewModel)
            } else if let loadError {
                Text(loadError)
                    .padding()
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            guard accountsViewModel == nil else { return }
            do {
                let persistence = try PersistenceService.makeDefault()
                accountsViewModel = AccountsViewModel(
                    accounts: DemoSeed.sampleAccounts,
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
}

#Preview {
    ContentView()
}
