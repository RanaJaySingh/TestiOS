import SwiftUI

/// Post-setup shell — Spec §4.3 Tab Bar: Goals | History | Ask (Settings via gear).
struct MainTabView: View {
    let persistence: any PersistenceServicing
    @StateObject private var goalsViewModel: GoalsViewModel

    init(persistence: any PersistenceServicing) {
        self.persistence = persistence
        _goalsViewModel = StateObject(
            wrappedValue: GoalsViewModel(persistence: persistence)
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                GoalsTabView(viewModel: goalsViewModel)
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            .accessibilityIdentifier("tab.goals")

            NavigationStack {
                HistoryTabView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .accessibilityIdentifier("tab.history")

            NavigationStack {
                AskTabView()
            }
            .tabItem {
                Label("Ask", systemImage: "bubble.left.and.bubble.right")
            }
            .accessibilityIdentifier("tab.ask")
        }
        .accessibilityIdentifier("main.tabBar")
    }
}

#Preview {
    MainTabView(persistence: PreviewPersistence())
}

/// In-memory persistence for SwiftUI previews.
private final class PreviewPersistence: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
