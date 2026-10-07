import SwiftUI

/// Accounts screen — design frame 2 (Step 1 of 3); Spec BR-1 / PRD R2 / visual R7.
struct AccountsView: View {
    @ObservedObject var viewModel: AccountsViewModel
    var onNavigateToConsent: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s24) {
                header
                accountsSection
                statusFooter
                continueButton
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .onChange(of: viewModel.shouldNavigateToConsent) { shouldNavigate in
            if shouldNavigate {
                onNavigateToConsent()
            }
        }
        .alert(
            "Couldn’t continue",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { /* cleared on next toggle */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Step 1 of 3")
                .font(PiTypography.caption())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityIdentifier("accounts.step")

            Text("Choose dedicated savings")
                .font(PiTypography.title())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("accounts.title")

            Text("Pick exactly one account as Dedicated savings. Spending stays untracked.")
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Step 1 of 3. Choose dedicated savings. Pick exactly one account as Dedicated savings."
        )
        .accessibilityIdentifier("accounts.header")
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            ForEach(viewModel.accounts) { account in
                accountCard(account)
            }
        }
        .accessibilityIdentifier("accounts.list")
    }

    private func accountCard(_ account: Account) -> some View {
        let title = viewModel.displayTitle(for: account)
        let role = viewModel.roleLabel(for: account)
        let balance = viewModel.formattedBalance(for: account)

        return PiCard(padding: DesignTokens.Space.s16) {
            HStack(alignment: .center, spacing: DesignTokens.Space.s12) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text(role)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                    Text(balance)
                        .font(PiTypography.body())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle(
                    "Dedicated",
                    isOn: Binding(
                        get: {
                            viewModel.accounts.first(where: { $0.id == account.id })?.isDedicated ?? false
                        },
                        set: { viewModel.setDedicated(accountID: account.id, isDedicated: $0) }
                    )
                )
                .labelsHidden()
                .tint(PiColors.navyPrimary)
                .accessibilityLabel("Dedicated savings for \(title)")
                .accessibilityValue(account.isDedicated ? "On" : "Off")
                .accessibilityHint(
                    account.isDedicated
                        ? "Turns off dedicated savings for this account"
                        : "Makes this the only dedicated savings account"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(role) \(title), balance \(balance)")
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(PiTypography.caption())
            .foregroundStyle(viewModel.canContinue ? .secondary : PiColors.behind)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("accounts.status")
    }

    @ViewBuilder
    private var continueButton: some View {
        if viewModel.isContinuing {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
                .accessibilityLabel("Continue")
        } else {
            PrimaryCTA(
                title: "Continue",
                isEnabled: viewModel.canContinue,
                accessibilityIdentifier: "accounts.continue"
            ) {
                Task { await viewModel.continueToConsent() }
            }
            .accessibilityHint(
                viewModel.canContinue
                    ? "Continues to Consent"
                    : "Enabled when exactly one account is dedicated"
            )
        }
    }
}

#Preview("None dedicated · Continue disabled") {
    NavigationStack {
        AccountsView(
            viewModel: AccountsViewModel(
                accounts: DemoSeed.sampleAccounts,
                persistence: PreviewAccountsPersistence()
            ),
            onNavigateToConsent: {}
        )
    }
}

#Preview("One dedicated · Continue enabled") {
    NavigationStack {
        AccountsView(
            viewModel: AccountsViewModel(
                accounts: DemoSeed.sampleAccounts.map { account in
                    var copy = account
                    copy.isDedicated = account.bankName == "HDFC"
                    return copy
                },
                persistence: PreviewAccountsPersistence()
            ),
            onNavigateToConsent: {}
        )
    }
}

/// In-memory persistence for SwiftUI previews only.
private actor PreviewAccountsPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
