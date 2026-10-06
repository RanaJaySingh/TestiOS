import SwiftUI

@main
struct PiPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            // PIP-33: project skeleton only — UI screens land in later tickets.
            ContentView()
        }
    }
}

/// Placeholder root view so the SwiftUI target builds. No product screens yet.
struct ContentView: View {
    var body: some View {
        Text("PiPlanner")
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
