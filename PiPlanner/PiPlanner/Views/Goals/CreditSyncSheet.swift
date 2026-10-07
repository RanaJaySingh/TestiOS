import SwiftUI

/// Sync sheet (frames 10 / 10a / 10b). Named `CreditSyncSheet` to avoid colliding with PIP-45 stub `SyncSheet`.
/// Visual parity (PIP-83 / PRD R11): PiSheet chrome, PiCard balance rows, +green New amount, Primary/Secondary CTAs.
struct CreditSyncSheet: View {
    @ObservedObject var viewModel: CreditSyncViewModel
    var onOpenCreditEntry: (HistoryEntry) -> Void
    var onWithdrawal: (Paisa) -> Void
    var onDismiss: () -> Void

    private let formatting = FormattingService()

    var body: some View {
        NavigationStack {
            PiSheet(title: "Balance sync", helper: syncHelper) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    balanceCard

                    if let info = viewModel.infoMessage {
                        Text(info)
                            .font(PiTypography.body())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("creditSync.info")
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(PiTypography.body())
                            .foregroundStyle(PiColors.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    actions
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
            }
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
        .background(PiColors.backgroundApp)
        .accessibilityIdentifier("credit.syncSheet")
    }

    /// Helper under title — idle hint only (same/down copy stays in body hierarchy).
    private var syncHelper: String? {
        if viewModel.phase == .idle, viewModel.fetchedBalance == nil, !viewModel.isBlockedByOpenEntry {
            return "Check the dedicated savings balance."
        }
        return nil
    }

    private var balanceCard: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                balanceRow(
                    label: "Previous",
                    value: viewModel.formattedPrevious,
                    emphasis: .standard
                )
                if let fetched = viewModel.formattedFetched {
                    balanceRow(
                        label: "Fetched",
                        value: fetched,
                        emphasis: .standard
                    )
                }
                if let newAmount = viewModel.formattedNewAmount {
                    // Design frame 10: New amount +₹… in positive green (prefix is visual only).
                    balanceRow(
                        label: "New amount",
                        value: "+\(newAmount)",
                        emphasis: .positive
                    )
                } else if case .lower(let shortfall, _, _)? = viewModel.compareResult {
                    // Design frame 10b: Went down by −₹… (presentation only; shortfall from compare).
                    balanceRow(
                        label: "Went down by",
                        value: formatting.formatINR(paisa: -shortfall),
                        emphasis: .negative
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creditSync.balanceRows")
    }

    private enum RowEmphasis {
        case standard
        case positive
        case negative
    }

    private func balanceRow(label: String, value: String, emphasis: RowEmphasis) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
            Spacer(minLength: DesignTokens.Space.s8)
            Text(value)
                .font(amountFont(for: emphasis))
                .fontWeight(emphasis == .standard ? .semibold : .bold)
                .foregroundStyle(amountColor(for: emphasis))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func amountFont(for emphasis: RowEmphasis) -> Font {
        switch emphasis {
        case .positive:
            return PiTypography.title()
        case .standard, .negative:
            return PiTypography.body()
        }
    }

    private func amountColor(for emphasis: RowEmphasis) -> Color {
        switch emphasis {
        case .standard:
            return .primary
        case .positive:
            return PiColors.positiveGreen
        case .negative:
            return PiColors.destructive
        }
    }

    @ViewBuilder
    private var actions: some View {
        if viewModel.phase == .syncing {
            ProgressView("Syncing…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
        } else if viewModel.canContinueToCreditEntry, let entry = viewModel.createdEntry {
            PrimaryCTA(
                title: "Continue",
                accessibilityIdentifier: "creditSync.continue"
            ) {
                onOpenCreditEntry(entry)
            }
        } else if let shortfall = viewModel.withdrawalShortfall {
            PrimaryCTA(
                title: "Continue to withdrawal",
                accessibilityIdentifier: "creditSync.withdrawal"
            ) {
                onWithdrawal(shortfall)
            }
        } else if viewModel.phase == .idle || viewModel.fetchedBalance == nil {
            PrimaryCTA(
                title: "Sync now",
                isEnabled: !viewModel.isBlockedByOpenEntry,
                accessibilityIdentifier: "creditSync.confirm"
            ) {
                Task { await viewModel.syncNow() }
            }
        }
    }
}
