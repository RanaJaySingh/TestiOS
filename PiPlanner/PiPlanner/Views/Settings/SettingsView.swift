import SwiftUI

/// Settings stub — consent toggle / Reset demo arrive in a later ticket.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Consent, Reset demo, and account preferences land in a later Settings ticket.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .accessibilityIdentifier("settings.view")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
