import SwiftUI

/// Update balance sheet (frames 11a–11c). Named to avoid PIP-45 `GoalsUpdateBalanceSheet`.
/// Visual parity: PIP-83 PiSheet / amount hierarchy (R11) + PIP-77 Update/UPI Demo chrome (R8).
/// No ViewModel / product-behaviour change.
struct CreditUpdateBalanceSheet: View {
    @ObservedObject var viewModel: CreditUpdateBalanceViewModel
    var onOpenCreditEntry: (HistoryEntry) -> Void
    /// PIP-107 — full shortfall / previous / new from `.withdrawalRequired`.
    var onWithdrawal: (WithdrawalPresentation) -> Void
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
                case .otherApp:
                    otherAppContent
                case .wrongPin:
                    wrongPinContent
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
            .onChange(of: viewModel.withdrawalPresentation) { presentation in
                if let presentation {
                    onWithdrawal(presentation)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .background(PiColors.backgroundApp)
        .accessibilityIdentifier("credit.updateBalanceSheet")
        .piPlannerTheme()
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

    /// PIP-77 Paytm-like choice rows (Manually / Balance sync) — not bordered CTAs.
    private var choiceRows: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            UpdateBalanceChoiceRow(
                title: "Manually",
                subtitle: "Type a new balance",
                systemImage: "pencil",
                isEnabled: !viewModel.isBlockedByOpenEntry,
                accessibilityIdentifier: "creditUpdate.manual",
                action: { viewModel.chooseManual() }
            )

            UpdateBalanceChoiceRow(
                title: "Balance sync",
                subtitle: "Check with demo UPI PIN",
                systemImage: PiIcons.sync,
                isEnabled: !viewModel.isBlockedByOpenEntry,
                accessibilityIdentifier: "creditUpdate.pin",
                action: { viewModel.chooseBalanceSync() }
            )

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
                                    .font(PiTypography.amountHero())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PiColors.navyPrimary)
                                TextField("0", text: $viewModel.rupeeDigits)
                                    .keyboardType(.numberPad)
                                    .font(PiTypography.amountHero())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PiColors.navyPrimary)
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

                if viewModel.isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Space.s12)
                } else {
                    PrimaryCTA(
                        title: "Continue",
                        isEnabled: viewModel.canContinueManual && !viewModel.isWorking,
                        accessibilityIdentifier: "creditUpdate.apply"
                    ) {
                        Task { await viewModel.applyTypedBalance() }
                    }
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
                VStack(spacing: DesignTokens.Space.s12) {
                    UPIDemoBadge()
                    UPIBankMaskedLine(title: viewModel.dedicatedBankTitle ?? "HDFC ••4821")
                }

                UPIPinDots(
                    filledCount: viewModel.pinDigits.count,
                    showsError: viewModel.pinError == .wrongPin
                )
                .frame(maxWidth: .infinity)
                .padding(.top, DesignTokens.Space.s8)

                if let pinError = viewModel.pinError, pinError != .wrongPin {
                    Text(String(describing: pinError))
                        .font(PiTypography.body())
                        .foregroundStyle(PiColors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                UPIMockPad(
                    isEnabled: !viewModel.isWorking,
                    onDigit: { viewModel.appendPINDigit($0) },
                    onDelete: { viewModel.deletePINDigit() }
                )

                if viewModel.isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Space.s12)
                } else {
                    PrimaryCTA(
                        title: "Check balance",
                        isEnabled: viewModel.canSubmitPIN,
                        accessibilityIdentifier: "creditUpdate.checkBalance"
                    ) {
                        Task { await viewModel.submitPIN() }
                    }
                }

                SecondaryCTA(
                    title: "Account on another UPI app",
                    style: .text,
                    accessibilityIdentifier: "creditUpdate.otherApp"
                ) {
                    viewModel.path = .otherApp
                }

                SecondaryCTA(
                    title: "Back",
                    style: .outline,
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

    // MARK: - Other UPI app → Manual only

    private var otherAppContent: some View {
        PiSheet(
            title: "Account on another UPI app",
            helper: "This savings account looks linked in another UPI app. Enter the balance manually."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                Spacer(minLength: 0)
                PrimaryCTA(
                    title: "Enter balance manually",
                    accessibilityIdentifier: "creditUpdate.otherAppManual"
                ) {
                    viewModel.continueFromOtherApp()
                }
                SecondaryCTA(
                    title: "Back",
                    style: .text,
                    accessibilityIdentifier: "creditUpdate.otherAppBack"
                ) {
                    viewModel.backToChoice()
                }
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

    // MARK: - Wrong PIN → retry / manual

    private var wrongPinContent: some View {
        PiSheet(
            title: "Incorrect PIN",
            helper: viewModel.errorMessage ?? "Incorrect PIN. Try again or enter the balance manually."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                UPIPinDots(filledCount: 4, showsError: true)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                PrimaryCTA(
                    title: "Try again",
                    accessibilityIdentifier: "creditUpdate.retryPin"
                ) {
                    viewModel.retryPIN()
                }
                SecondaryCTA(
                    title: "Enter manually",
                    style: .outline,
                    accessibilityIdentifier: "creditUpdate.wrongPinManual"
                ) {
                    viewModel.enterManuallyAfterWrongPin()
                }
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
