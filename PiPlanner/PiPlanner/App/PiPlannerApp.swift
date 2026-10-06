import SwiftUI

@main
struct PiPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Root host. Until earlier setup screens land, Opening split is reachable for PIP-43 demos.
struct ContentView: View {
    @State private var openingSplitViewModel: OpeningSplitViewModel?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let openingSplitViewModel {
                OpeningSplitFlowView(viewModel: openingSplitViewModel)
            } else if let loadError {
                Text(loadError)
                    .padding()
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            guard openingSplitViewModel == nil else { return }
            do {
                let persistence = try PersistenceService.makeDefault()
                openingSplitViewModel = OpeningSplitViewModel(
                    goals: DemoSeed.sampleGoals,
                    openingBalance: DemoSeed.openingBalancePaisa,
                    persistence: persistence
                )
            } catch {
                loadError = error.localizedDescription
            }
        }
    }
}

/// Minimal seed so Opening split can be exercised before Welcome → Goals setup exists.
enum DemoSeed {
    static let openingBalancePaisa: Paisa = 10_000_000 // ₹1,00,000

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
