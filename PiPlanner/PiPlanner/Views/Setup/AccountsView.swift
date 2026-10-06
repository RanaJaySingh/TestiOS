import SwiftUI

/// Accounts screen — design frame 2 (Step 1 of 3); Spec BR-1 / PRD R2.
struct AccountsView: View {
    @ObservedObject var viewModel: AccountsViewModel
    var onNavigateToConsent: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                accountsSection
                statusFooter
                continueButton
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 1 of 3")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Choose dedicated savings")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Pick exactly one account as Dedicated savings. Spending stays untracked.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Step 1 of 3. Choose dedicated savings. Pick exactly one account as Dedicated savings."
        )
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.accounts) { account in
                accountRow(account)
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        let title = viewModel.displayTitle(for: account)
        let role = viewModel.roleLabel(for: account)
        let balance = viewModel.formattedBalance(for: account)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                Text(balance)
                    .font(.subheadline)
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
            .accessibilityLabel("Dedicated savings for \(title)")
            .accessibilityValue(account.isDedicated ? "On" : "Off")
            .accessibilityHint(
                account.isDedicated
                    ? "Turns off dedicated savings for this account"
                    : "Makes this the only dedicated savings account"
            )
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(role) \(title), balance \(balance)")
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.callout)
            .foregroundStyle(viewModel.canContinue ? .secondary : .orange)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var continueButton: some View {
        Button {
            Task { await viewModel.continueToConsent() }
        } label: {
            Group {
                if viewModel.isContinuing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canContinue)
        .accessibilityLabel("Continue")
        .accessibilityHint(
            viewModel.canContinue
                ? "Continues to Consent"
                : "Enabled when exactly one account is dedicated"
        )
    }
}

#Preview("None dedicated") {
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

#Preview("One dedicated") {
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
