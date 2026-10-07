import SwiftUI

/// Sync sheet (frames 10 / 10a / 10b). Named `CreditSyncSheet` to avoid colliding with PIP-45 stub `SyncSheet`.
struct CreditSyncSheet: View {
    @ObservedObject var viewModel: CreditSyncViewModel
    var onOpenCreditEntry: (HistoryEntry) -> Void
    var onWithdrawal: (Paisa) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sync balance")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                balanceRows

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("creditSync.info")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions
                Spacer(minLength: 0)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
            .task {
                await viewModel.loadAndPrepare()
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("credit.syncSheet")
    }

    private var balanceRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("Previous", viewModel.formattedPrevious)
            if let fetched = viewModel.formattedFetched {
                labeledRow("Fetched", fetched)
            }
            if let newAmount = viewModel.formattedNewAmount {
                labeledRow("New amount", newAmount)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var actions: some View {
        if viewModel.phase == .syncing {
            ProgressView("Syncing…")
                .frame(maxWidth: .infinity)
        } else if viewModel.canContinueToCreditEntry, let entry = viewModel.createdEntry {
            Button("Continue") {
                onOpenCreditEntry(entry)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("creditSync.continue")
        } else if let shortfall = viewModel.withdrawalShortfall {
            Button("Continue to withdrawal") {
                onWithdrawal(shortfall)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("creditSync.withdrawal")
        } else if viewModel.phase == .idle || viewModel.fetchedBalance == nil {
            Button("Sync now") {
                Task { await viewModel.syncNow() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBlockedByOpenEntry)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("creditSync.confirm")
        }
    }
}
