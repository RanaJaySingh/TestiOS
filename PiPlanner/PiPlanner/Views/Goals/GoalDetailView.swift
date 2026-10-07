import SwiftUI

/// Minimal Goal detail placeholder (full CRUD in later tickets).
struct GoalDetailView: View {
    let goal: Goal?
    let formattedSaved: String
    let statusLabel: String

    var body: some View {
        List {
            Section("Goal") {
                LabeledContent("Name", value: goal?.name ?? "—")
                LabeledContent("Saved", value: formattedSaved)
                LabeledContent("Status", value: statusLabel)
            }
            Section {
                Text("Edit, standing split, delete, transfer, and withdrawal arrive in later tickets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(goal?.name ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("goals.detail")
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(
            goal: DemoSeed.sampleGoals[0],
            formattedSaved: "₹60,000",
            statusLabel: "On track"
        )
    }
}
