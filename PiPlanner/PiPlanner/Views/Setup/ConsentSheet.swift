import SwiftUI

/// Consent sheet — design frame 3 (PRD R3 / R4 / visual R7); Settings re-open 20b (PRD R17).
///
/// Paytm-like sheet chrome via `PiSheet`; behaviour unchanged (Yes fetch / No path / Settings flags).
struct ConsentSheet: View {
    @ObservedObject var viewModel: ConsentViewModel
    /// Setup shows “Step 2 of 3”; Settings (20b) hides the step label.
    var showsSetupStep: Bool = true
    /// Setup Yes fetches opening balance; Settings Yes only grants auto-update.
    var fetchesBalanceOnYes: Bool = true
    var onYesFetched: () -> Void
    var onNo: () -> Void

    var body: some View {
        PiSheet(title: "Allow balance checks?", helper: sheetHelper) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s24) {
                    if showsSetupStep {
                        Text("Step 2 of 3")
                            .font(PiTypography.caption())
                            .foregroundStyle(PiColors.navyPrimary)
                            .accessibilityIdentifier("consent.step")
                    }
                    bullets
                    actions
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.bottom, DesignTokens.Space.s28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        // Keep the nav back chevron on setup push; title lives in PiSheet chrome.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .alert(
            "Couldn’t update balance",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.isWorking },
                set: { if !$0 { /* cleared on next action */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var sheetHelper: String {
        if let title = viewModel.dedicatedAccountTitle {
            return "Asked for \(title), where credits arrive."
        }
        return "Asked for the account where credits arrive."
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
            ForEach(Array(ConsentService.consentBullets.enumerated()), id: \.offset) { index, bullet in
                HStack(alignment: .top, spacing: DesignTokens.Space.s12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DesignTokens.TypeSize.body, weight: .semibold))
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(PiTypography.body())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("consent.bullet.\(index)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ConsentService.consentBullets.joined(separator: ". "))
        .accessibilityIdentifier("consent.bullets")
    }

    private var actions: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            if viewModel.isWorking {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
                    .accessibilityLabel("Yes, update automatically")
            } else {
                PrimaryCTA(
                    title: "Yes, update automatically",
                    isEnabled: true,
                    accessibilityIdentifier: "consent.yes"
                ) {
                    Task {
                        if fetchesBalanceOnYes {
                            if await viewModel.chooseConsentYes() != nil {
                                onYesFetched()
                            }
                        } else {
                            // Settings (20b): host persists consent On without re-fetching balance.
                            onYesFetched()
                        }
                    }
                }
                .accessibilityHint(
                    fetchesBalanceOnYes
                        ? "Fetches opening balance for the dedicated account"
                        : "Turns on automatic balance updates"
                )
            }

            SecondaryCTA(
                title: "No, I’ll update it myself",
                style: .outline,
                isEnabled: !viewModel.isWorking,
                accessibilityIdentifier: "consent.no"
            ) {
                viewModel.chooseConsentNo()
                onNo()
            }
            .accessibilityHint("Opens Update balance options")
        }
    }
}

/// Opening balance fetched — design frame 3a (Consent Yes / PIN success); visual R7.
struct FetchedBalanceView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s24) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Step 2 of 3")
                    .font(PiTypography.caption())
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityIdentifier("fetchedBalance.step")

                Text("Opening balance")
                    .font(PiTypography.title())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("fetchedBalance.title")

                Text("Fetched from your dedicated savings account.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PiCard(padding: DesignTokens.Space.s20) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text("Balance")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                    Text(viewModel.formattedResolvedBalance)
                        .font(PiTypography.amountHero())
                        .foregroundStyle(PiColors.navyPrimary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .accessibilityLabel("Balance \(viewModel.formattedResolvedBalance)")
                        .accessibilityIdentifier("fetchedBalance.amount")
                }
            }

            Spacer(minLength: 0)

            PrimaryCTA(
                title: "Continue",
                isEnabled: true,
                accessibilityIdentifier: "fetchedBalance.continue"
            ) {
                onContinue()
            }
            .accessibilityHint("Continues setup with this opening balance")
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
    }
}

/// Update balance sheet (setup) — design frame 4 (Consent No). Paytm-like choice rows (PIP-77).
struct UpdateBalanceSheet: View {
    var onManually: () -> Void
    var onBalanceSync: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text("Update balance")
                        .font(PiTypography.title())
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    Text("How do you want to set the opening balance?")
                        .font(PiTypography.body())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: DesignTokens.Space.s12) {
                    UpdateBalanceChoiceRow(
                        title: "Manually",
                        subtitle: "Type the opening balance",
                        systemImage: "pencil",
                        accessibilityIdentifier: "updateBalance.manually",
                        action: onManually
                    )
                    .accessibilityLabel("Manually")
                    .accessibilityHint("Type the opening balance")

                    UpdateBalanceChoiceRow(
                        title: "Balance sync",
                        subtitle: "Check with demo UPI PIN",
                        systemImage: PiIcons.sync,
                        accessibilityIdentifier: "updateBalance.balanceSync",
                        action: onBalanceSync
                    )
                    .accessibilityLabel("Balance sync")
                    .accessibilityHint("Opens demo UPI PIN")
                }
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Update balance")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
    }
}

/// Account on another UPI app — design frame 4c (forces manual). PIP-77 chrome.
struct OtherAppView: View {
    var onContinueManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Account on another UPI app")
                    .font(PiTypography.title())
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "This savings account looks linked in another UPI app. Enter the balance manually to continue setup."
                )
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            PrimaryCTA(title: "Enter balance manually", action: onContinueManual)
                .accessibilityLabel("Enter balance manually")
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Another UPI app")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
    }
}

/// Wrong PIN — design frames 4d / 4e (retry or manual). PIP-77 chrome (no logic change).
struct WrongPinView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onRetry: () -> Void
    var onManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Incorrect PIN")
                    .font(PiTypography.title())
                    .foregroundStyle(PiColors.destructive)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.errorMessage ?? "Incorrect PIN. Try again or enter the balance manually.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            UPIPinDots(filledCount: 4, showsError: true)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            VStack(spacing: DesignTokens.Space.s12) {
                PrimaryCTA(title: "Try again") {
                    viewModel.retryPIN()
                    onRetry()
                }
                .accessibilityLabel("Try again")

                SecondaryCTA(title: "Enter manually", style: .outline) {
                    viewModel.clearPIN()
                    onManual()
                }
                .accessibilityLabel("Enter manually")
            }
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("UPI PIN")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
    }
}

#Preview("Consent · Yes / No") {
    NavigationStack {
        ConsentSheet(
            viewModel: ConsentViewModel(
                accounts: DemoSeed.sampleAccounts.map { account in
                    var copy = account
                    copy.isDedicated = account.bankName == "HDFC"
                    return copy
                },
                persistence: PreviewConsentPersistence()
            ),
            onYesFetched: {},
            onNo: {}
        )
    }
}

#Preview("Consent · Settings 20b") {
    NavigationStack {
        ConsentSheet(
            viewModel: ConsentViewModel(
                accounts: DemoSeed.postSetupAccounts(consentAutoUpdate: false),
                persistence: PreviewConsentPersistence()
            ),
            showsSetupStep: false,
            fetchesBalanceOnYes: false,
            onYesFetched: {},
            onNo: {}
        )
    }
}

#Preview("Fetched balance 3a · ₹1,00,000") {
    FetchedBalancePreviewHost()
}

/// Loads demo opening balance for the 3a preview only.
private struct FetchedBalancePreviewHost: View {
    @StateObject private var viewModel = ConsentViewModel(
        accounts: DemoSeed.sampleAccounts.map { account in
            var copy = account
            copy.isDedicated = account.bankName == "HDFC"
            return copy
        },
        persistence: PreviewConsentPersistence()
    )

    var body: some View {
        NavigationStack {
            FetchedBalanceView(viewModel: viewModel, onContinue: {})
                .task { _ = await viewModel.chooseConsentYes() }
        }
    }
}

/// In-memory persistence for SwiftUI previews only.
private actor PreviewConsentPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
