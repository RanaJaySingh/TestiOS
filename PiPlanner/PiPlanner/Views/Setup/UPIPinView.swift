import SwiftUI

/// UPI PIN (Demo) — design frame 4b (PRD R4). Demo PIN `"1234"`.
struct UPIPinView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onSuccess: () -> Void
    var onWrongPin: () -> Void
    var onCancel: () -> Void
    var onOtherApp: () -> Void

    private let padRows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 24) {
            header
            pinDots
            pad
            actions
            otherAppLink
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("UPI PIN")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Demo UPI PIN")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Enter the 4-digit demo PIN to check balance. Demo PIN is 1234.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var pinDots: some View {
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.secondary, lineWidth: 1.5)
                    .background(
                        Circle().fill(index < viewModel.pinDigits.count ? Color.primary : Color.clear)
                    )
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PIN entered \(viewModel.pinDigits.count) of 4 digits")
    }

    private var pad: some View {
        VStack(spacing: 12) {
            ForEach(padRows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        padKey(key)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func padKey(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        } else {
            Button {
                if key == "⌫" {
                    viewModel.deletePINDigit()
                } else {
                    viewModel.appendPINDigit(key)
                }
            } label: {
                Text(key)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isWorking)
            .accessibilityLabel(key == "⌫" ? "Delete" : key)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
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
            } label: {
                Group {
                    if viewModel.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Check balance")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canCheckPIN)
            .accessibilityLabel("Check balance")

            Button {
                _ = viewModel.cancelPIN()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isWorking)
            .accessibilityLabel("Cancel")
        }
    }

    private var otherAppLink: some View {
        Button {
            _ = viewModel.accountOnOtherUPIApp()
            onOtherApp()
        } label: {
            Text("Account on another UPI app")
                .font(.subheadline)
        }
        .disabled(viewModel.isWorking)
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
