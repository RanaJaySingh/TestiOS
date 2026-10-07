import SwiftUI

/// Stub Sync sheet for Consent On — calls BalanceSyncService; full credit entry later.
struct SyncSheet: View {
    let isSyncing: Bool
    var onSync: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Sync balance")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text("We’ll read the dedicated savings balance. Credit assignment locks in a later ticket.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if isSyncing {
                    ProgressView("Syncing…")
                } else {
                    Button("Sync now", action: onSync)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("sync.confirm")
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("goals.syncSheet")
    }
}

#Preview {
    SyncSheet(isSyncing: false, onSync: {}, onDismiss: {})
}
