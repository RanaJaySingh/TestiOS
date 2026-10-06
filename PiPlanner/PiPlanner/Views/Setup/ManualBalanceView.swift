import SwiftUI

/// Manual amount · setup — design frame 4a (PRD R4). Continue disabled at ₹0.
struct ManualBalanceView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            amountField
            Spacer(minLength: 0)
            continueButton
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Manual amount")
        .navigationBarTitleDisplayMode(.inline)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter opening balance")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Type the current balance of your dedicated savings. No withdrawal link during setup.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.title)
                    .fontWeight(.semibold)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.manualRupeeDigits },
                        set: { viewModel.setManualRupeeDigits($0) }
                    )
                )
                .keyboardType(.numberPad)
                .font(.title)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityLabel("Opening balance in rupees")
            }
            Text(viewModel.formattedManualAmount)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("Formatted amount \(viewModel.formattedManualAmount)")
        }
    }

    private var continueButton: some View {
        Button {
            Task {
                if await viewModel.continueManual() != nil {
                    onContinue()
                }
            }
        } label: {
            Group {
                if viewModel.isWorking {
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
        .disabled(!viewModel.canContinueManual)
        .accessibilityLabel("Continue")
        .accessibilityHint(
            viewModel.canContinueManual
                ? "Continues with the typed opening balance"
                : "Enabled when amount is greater than zero"
        )
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
