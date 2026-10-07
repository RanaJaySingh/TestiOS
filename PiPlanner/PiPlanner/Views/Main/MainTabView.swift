import SwiftUI

/// Post-setup shell — Spec §4.3 / §3.4 Tab Bar: Goals | History | Ask (Settings via gear).
/// PIP-71: Material-style SF Symbol catalog + navy selected-state chrome (visual only).
struct MainTabView: View {
    let persistence: any PersistenceServicing
    /// Bubbles Settings → Reset demo up to `ContentView` for Welcome (1).
    var onDemoReset: (() -> Void)?
    @StateObject private var goalsViewModel: GoalsViewModel
    @State private var selectedTab: MainTabChrome.Tab = .goals

    init(
        persistence: any PersistenceServicing,
        onDemoReset: (() -> Void)? = nil
    ) {
        self.persistence = persistence
        self.onDemoReset = onDemoReset
        _goalsViewModel = StateObject(
            wrappedValue: GoalsViewModel(persistence: persistence)
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                GoalsTabView(
                    viewModel: goalsViewModel,
                    onDemoReset: onDemoReset
                )
            }
            .tabItem {
                tabLabel(for: .goals)
            }
            .tag(MainTabChrome.Tab.goals)
            .accessibilityIdentifier(MainTabChrome.Tab.goals.accessibilityIdentifier)

            NavigationStack {
                HistoryTabView(persistence: persistence)
            }
            .tabItem {
                tabLabel(for: .history)
            }
            .tag(MainTabChrome.Tab.history)
            .accessibilityIdentifier(MainTabChrome.Tab.history.accessibilityIdentifier)

            NavigationStack {
                AskTabView(
                    persistence: persistence,
                    goals: goalsViewModel.goals,
                    standingSplits: goalsViewModel.standingSplits,
                    accounts: goalsViewModel.accounts,
                    formatting: goalsViewModel.formatting
                )
            }
            .tabItem {
                tabLabel(for: .ask)
            }
            .tag(MainTabChrome.Tab.ask)
            .accessibilityIdentifier(MainTabChrome.Tab.ask.accessibilityIdentifier)
        }
        // Selected tab chrome: navy primary from PIP-67 tokens (not bright Accent / purple).
        .tint(PiColors.navyPrimary)
        .accessibilityIdentifier("main.tabBar")
    }

    @ViewBuilder
    private func tabLabel(for tab: MainTabChrome.Tab) -> some View {
        let selected = selectedTab == tab
        Label(
            tab.title,
            systemImage: tab.systemImage(selected: selected)
        )
    }
}

#Preview {
    MainTabView(persistence: PreviewPersistence())
        .piPlannerTheme()
}

/// In-memory persistence for SwiftUI previews.
private final class PreviewPersistence: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
