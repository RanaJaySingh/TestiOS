import SwiftUI

/// Update balance sheet (frames 11a–11c). Named to avoid PIP-45 `GoalsUpdateBalanceSheet`.
/// Visual parity (PIP-83 / PRD R11): Paytm-like PiSheet choice chrome, amount field, PIN pad CTAs.
struct CreditUpdateBalanceSheet: View {
    @ObservedObject var viewModel: CreditUpdateBalanceViewModel
    var onOpenCreditEntry: (HistoryEntry) -> Void
    var onWithdrawal: (Paisa) -> Void
    /// Optional manual path (frame 18c / 11a "Record a withdrawal" link).
    var onRecordWithdrawal: (() -> Void)? = nil
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.path {
                case .choice:
                    choiceContent
                case .manual:
                    manualContent
                case .pin:
                    pinContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
            .task {
                await viewModel.loadAndPrepare()
            }
            .onChange(of: viewModel.createdEntry?.id) { _ in
                if let entry = viewModel.createdEntry {
                    onOpenCreditEntry(entry)
                }
            }
            .onChange(of: viewModel.withdrawalShortfall) { shortfall in
                if let shortfall {
                    onWithdrawal(shortfall)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .background(PiColors.backgroundApp)
        .accessibilityIdentifier("credit.updateBalanceSheet")
    }

    // MARK: - 11a Choice

    private var choiceContent: some View {
        PiSheet(
            title: "Update balance",
            helper: "How do you want to update the dedicated savings balance?"
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                PiCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                        Text("Current")
                            .font(PiTypography.caption())
                            .foregroundStyle(.secondary)
                        Text(viewModel.formattedPrevious)
                            .font(PiTypography.title())
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                }

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(PiTypography.body())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("creditUpdate.info")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(PiTypography.body())
                        .foregroundStyle(PiColors.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }

                choiceRows

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
    }

    private var choiceRows: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            PrimaryCTA(
                title: "Manually",
                isEnabled: !viewModel.isBlockedByOpenEntry,
                accessibilityIdentifier: "creditUpdate.manual"
            ) {
                viewModel.chooseManual()
            }

            SecondaryCTA(
                title: "Balance sync",
                style: .outline,
                isEnabled: !viewModel.isBlockedByOpenEntry,
                accessibilityIdentifier: "creditUpdate.pin"
            ) {
                viewModel.chooseBalanceSync()
            }

            if let onRecordWithdrawal {
                SecondaryCTA(
                    title: "Record a withdrawal",
                    style: .text,
                    accessibilityIdentifier: "creditUpdate.recordWithdrawal"
                ) {
                    onRecordWithdrawal()
                }
            }
        }
    }

    // MARK: - 11b Manual amount

    private var manualContent: some View {
        PiSheet(
            title: "Manual amount",
            helper: "Type the new balance. Typed balances open a History entry with a Typed badge."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                PiCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                            Text("Current")
                                .font(PiTypography.caption())
                                .foregroundStyle(.secondary)
                            Text(viewModel.formattedPrevious)
                                .font(PiTypography.body())
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }

                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                            Text("New balance")
                                .font(PiTypography.caption())
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.s8) {
                                Text("₹")
                                    .font(PiTypography.title())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PiColors.navyPrimary)
                                TextField("0", text: $viewModel.rupeeDigits)
                                    .keyboardType(.numberPad)
                                    .font(PiTypography.title())
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .accessibilityIdentifier("creditUpdate.digits")
                            }
                        }
                    }
                }

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(PiTypography.body())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(PiTypography.body())
                        .foregroundStyle(PiColors.destructive)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryCTA(
                    title: "Continue",
                    isEnabled: viewModel.canContinueManual && !viewModel.isWorking,
                    accessibilityIdentifier: "creditUpdate.apply"
                ) {
                    Task { await viewModel.applyTypedBalance() }
                }

                SecondaryCTA(
                    title: "Back",
                    style: .text,
                    accessibilityIdentifier: "creditUpdate.manualBack"
                ) {
                    viewModel.backToChoice()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { viewModel.backToChoice() }
            }
        }
    }

    // MARK: - 11c UPI PIN (Demo)

    private var pinContent: some View {
        PiSheet(
            title: "Balance sync",
            helper: "Demo UPI PIN — enter 1234 to fetch balance. No money is debited."
        ) {
            VStack(spacing: DesignTokens.Space.s20) {
                HStack(spacing: DesignTokens.Space.s12) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.pinDigits.count ? PiColors.navyPrimary : Color.clear)
                            .overlay(
                                Circle().strokeBorder(
                                    PiColors.navyPrimary.opacity(0.45),
                                    lineWidth: 1.5
                                )
                            )
                            .frame(width: 14, height: 14)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignTokens.Space.s8)
                .accessibilityLabel("PIN digits entered \(viewModel.pinDigits.count) of 4")

                if let pinError = viewModel.pinError {
                    Text(pinError == .wrongPin ? "Incorrect PIN. Try again." : String(describing: pinError))
                        .font(PiTypography.body())
                        .foregroundStyle(PiColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 3),
                    spacing: DesignTokens.Space.s12
                ) {
                    ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"], id: \.self) { key in
                        Button {
                            if key == "⌫" {
                                viewModel.deletePINDigit()
                            } else if !key.isEmpty {
                                viewModel.appendPINDigit(key)
                            }
                        } label: {
                            Text(key)
                                .font(PiTypography.title())
                                .foregroundStyle(PiColors.navyPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: DesignTokens.Radius.chip,
                                        style: .continuous
                                    )
                                    .fill(key.isEmpty ? Color.clear : PiColors.chipLightBlue.opacity(0.55))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(key.isEmpty)
                    }
                }

                PrimaryCTA(
                    title: "Check balance",
                    isEnabled: viewModel.canSubmitPIN,
                    accessibilityIdentifier: "creditUpdate.checkBalance"
                ) {
                    Task { await viewModel.submitPIN() }
                }

                SecondaryCTA(
                    title: "Back",
                    style: .text,
                    accessibilityIdentifier: "creditUpdate.pinBack"
                ) {
                    viewModel.backToChoice()
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { viewModel.backToChoice() }
            }
        }
    }
}
