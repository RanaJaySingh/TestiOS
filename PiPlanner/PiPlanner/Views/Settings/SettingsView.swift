import SwiftUI

/// Settings — gear from Goals tab. Standing split (PIP-51); consent / Reset demo arrive later.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let goals: [Goal]
    let standingSplits: [StandingSplit]
    let persistence: any PersistenceServicing

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Splits") {
                    if goals.isEmpty {
                        Text("Add a goal before setting a standing split.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        NavigationLink(value: SettingsRoute.standingSplit) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Standing split")
                                    .font(.body)
                                Text(
                                    StandingSplitService.shouldPresentEditor(goalCount: goals.count)
                                        ? "Default shares for the next credit"
                                        : "One goal — 100% automatic"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("settings.standingSplit")
                    }
                }

                Section {
                    Text("Consent, Reset demo, and account preferences land in a later Settings ticket.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .standingSplit:
                    StandingSplitView(
                        viewModel: StandingSplitViewModel(
                            goals: goals,
                            persistence: persistence,
                            standingSplits: standingSplits
                        ),
                        onDismiss: {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .accessibilityIdentifier("settings.view")
        }
    }
}

private enum SettingsRoute: Hashable {
    case standingSplit
}

#Preview {
    SettingsView(
        goals: [],
        standingSplits: [],
        persistence: SettingsPreviewPersistence()
    )
}

private actor SettingsPreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
