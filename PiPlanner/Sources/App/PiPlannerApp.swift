import SwiftUI
import SwiftData

@main
struct PiPlannerApp: App {
    let modelContainer: ModelContainer
    @StateObject private var appState = AppState()
    
    init() {
        do {
            let schema = Schema([
                Account.self,
                Goal.self,
                HistoryEntry.self,
                UserSettings.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}
