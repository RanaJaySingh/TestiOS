import SwiftUI

/// Manual amount · setup — design frame 4a (PRD R4 / R8). Continue disabled at ₹0 (PIP-77 chrome).
struct ManualBalanceView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
            header
            amountCard
            Spacer(minLength: 0)
            continueButton
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Manual amount")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .alert(
            "Couldn’t save balance",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.isWorking },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text("Enter opening balance")
                .font(PiTypography.title())
                .accessibilityAddTraits(.isHeader)
            Text("Type the current balance of your dedicated savings. No withdrawal link during setup.")
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var amountCard: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Amount")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("₹")
                        .font(PiTypography.amountHero())
                        .foregroundStyle(PiColors.navyPrimary)
                    TextField(
                        "0",
                        text: Binding(
                            get: { viewModel.manualRupeeDigits },
                            set: { viewModel.setManualRupeeDigits($0) }
                        )
                    )
                    .keyboardType(.numberPad)
                    .font(PiTypography.amountHero())
                    .foregroundStyle(PiColors.navyPrimary)
                    .monospacedDigit()
                    .accessibilityLabel("Opening balance in rupees")
                }
                Text(viewModel.formattedManualAmount)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("Formatted amount \(viewModel.formattedManualAmount)")
            }
        }
    }

    @ViewBuilder
    private var continueButton: some View {
        if viewModel.isWorking {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
        } else {
            PrimaryCTA(
                title: "Continue",
                isEnabled: viewModel.canContinueManual,
                accessibilityIdentifier: "manualBalance.continue"
            ) {
                Task {
                    if await viewModel.continueManual() != nil {
                        onContinue()
                    }
                }
            }
            .accessibilityLabel("Continue")
            .accessibilityHint(
                viewModel.canContinueManual
                    ? "Continues with the typed opening balance"
                    : "Enabled when amount is greater than zero"
            )
        }
    }
}

#Preview {
    NavigationStack {
        ManualBalanceView(
            viewModel: ConsentViewModel(
                accounts: DemoSeed.sampleAccounts.map { account in
                    var copy = account
                    copy.isDedicated = account.bankName == "HDFC"
                    return copy
                },
                persistence: PreviewManualPersistence()
            ),
            onContinue: {}
        )
    }
}

private actor PreviewManualPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
