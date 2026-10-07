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
                    MainTabView(
                        persistence: persistence,
                        onDemoReset: {
                            returnToWelcome(persistence: persistence)
                        }
                    )
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
                    try await persistence.saveState(DemoData.postSetupState(consentAutoUpdate: true))
                }
                let state = try await persistence.loadState()
                destination = AppLaunchRouter.destination(for: state)
                self.persistence = persistence
                // First launch / post–Reset: empty persistence → seed Rahul persona accounts (PIP-65).
                accountsViewModel = AccountsViewModel(
                    accounts: state.accounts.isEmpty ? DemoData.sampleAccounts : state.accounts,
                    persistence: persistence
                )
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    /// Settings → Reset demo (PRD R17 / PIP-61) — clear host and reseed persona accounts for Welcome (1).
    private func returnToWelcome(persistence: PersistenceService) {
        accountsViewModel = AccountsViewModel(
            accounts: DemoData.sampleAccounts,
            persistence: persistence
        )
        destination = .welcome
    }
}

#Preview {
    ContentView()
}
