import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings: Bool = false
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                GoalsHomeView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }
            .tag(AppState.MainTab.goals)
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(AppState.MainTab.history)
            
            NavigationStack {
                AskView()
            }
            .tabItem {
                Label("Ask", systemImage: "sparkles")
            }
            .tag(AppState.MainTab.ask)
        }
        .tint(Theme.primaryNavy)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
