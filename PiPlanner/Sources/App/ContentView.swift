import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    var body: some View {
        Group {
            if hasCompletedSetup {
                MainTabView()
            } else {
                SetupFlowView()
            }
        }
        .onAppear {
            initializeIfNeeded()
        }
    }
    
    private var hasCompletedSetup: Bool {
        settings.first?.hasCompletedSetup ?? false
    }
    
    private func initializeIfNeeded() {
        if settings.isEmpty {
            let newSettings = UserSettings()
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
