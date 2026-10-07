import SwiftUI

/// UPI PIN (Demo) — design frame 4b (PRD R4 / R8). Demo PIN `"1234"`. PIP-77 chrome.
struct UPIPinView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onSuccess: () -> Void
    var onWrongPin: () -> Void
    var onCancel: () -> Void
    var onOtherApp: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Space.s24) {
                header
                pinDots
                pad
                actions
                otherAppLink
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("UPI PIN")
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
    }

    private var header: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            UPIDemoBadge()

            if let bank = viewModel.dedicatedAccountTitle {
                UPIBankMaskedLine(title: bank)
            }

            Text("Enter the 4-digit demo PIN to check balance.")
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Demo PIN is 1234")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var pinDots: some View {
        UPIPinDots(filledCount: viewModel.pinDigits.count)
    }

    private var pad: some View {
        UPIMockPad(
            isEnabled: !viewModel.isWorking,
            onDigit: { viewModel.appendPINDigit($0) },
            onDelete: { viewModel.deletePINDigit() }
        )
    }

    private var actions: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            if viewModel.isWorking {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
            } else {
                PrimaryCTA(
                    title: "Check balance",
                    isEnabled: viewModel.canCheckPIN,
                    accessibilityIdentifier: "upi.checkBalance"
                ) {
                    Task {
                        let outcome = await viewModel.checkBalanceWithPIN()
                        switch outcome {
                        case .success:
                            onSuccess()
                        case .wrongPin:
                            onWrongPin()
                        case .cancelled:
                            onCancel()
                        case .otherApp:
                            onOtherApp()
                        }
                    }
                }
                .accessibilityLabel("Check balance")
            }

            SecondaryCTA(
                title: "Cancel",
                style: .outline,
                isEnabled: !viewModel.isWorking,
                accessibilityIdentifier: "upi.cancel"
            ) {
                _ = viewModel.cancelPIN()
                onCancel()
            }
            .accessibilityLabel("Cancel")
        }
    }

    private var otherAppLink: some View {
        SecondaryCTA(
            title: "Account on another UPI app",
            style: .text,
            isEnabled: !viewModel.isWorking,
            accessibilityIdentifier: "upi.otherApp"
        ) {
            _ = viewModel.accountOnOtherUPIApp()
            onOtherApp()
        }
        .accessibilityLabel("Account on another UPI app")
        .accessibilityHint("Continues with manual balance entry")
    }
}

#Preview {
    NavigationStack {
        UPIPinView(
            viewModel: ConsentViewModel(
                accounts: DemoSeed.sampleAccounts.map { account in
                    var copy = account
                    copy.isDedicated = account.bankName == "HDFC"
                    return copy
                },
                persistence: PreviewUPIPersistence()
            ),
            onSuccess: {},
            onWrongPin: {},
            onCancel: {},
            onOtherApp: {}
        )
    }
}

private actor PreviewUPIPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
