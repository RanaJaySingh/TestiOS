import SwiftUI

/// Update balance sheet (frames 11a–11c). Named to avoid PIP-45 `GoalsUpdateBalanceSheet`.
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
        .accessibilityIdentifier("credit.updateBalanceSheet")
    }

    private var choiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Update balance")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("Current: \(viewModel.formattedPrevious)")
                .foregroundStyle(.secondary)

            if let info = viewModel.infoMessage {
                Text(info)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("creditUpdate.info")
            }

            Button("Manually") {
                viewModel.chooseManual()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBlockedByOpenEntry)
            .accessibilityIdentifier("creditUpdate.manual")

            Button("Balance sync") {
                viewModel.chooseBalanceSync()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isBlockedByOpenEntry)
            .accessibilityIdentifier("creditUpdate.pin")

            if let onRecordWithdrawal {
                Button("Record a withdrawal") {
                    onRecordWithdrawal()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("creditUpdate.recordWithdrawal")
            }

            Spacer()
        }
        .padding()
    }

    private var manualContent: some View {
        Form {
            Section {
                Text("Current: \(viewModel.formattedPrevious)")
                    .foregroundStyle(.secondary)
                TextField("New balance (₹)", text: $viewModel.rupeeDigits)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("creditUpdate.digits")
            } footer: {
                Text("Typed balances open a History entry with a Typed badge (13t).")
            }

            if let info = viewModel.infoMessage {
                Section {
                    Text(info)
                }
            }
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Manual amount")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") {
                    Task { await viewModel.applyTypedBalance() }
                }
                .disabled(!viewModel.canContinueManual || viewModel.isWorking)
                .accessibilityIdentifier("creditUpdate.apply")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { viewModel.backToChoice() }
            }
        }
    }

    private var pinContent: some View {
        VStack(spacing: 20) {
            Text("Demo UPI PIN")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Enter 1234 to fetch balance.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.pinDigits.count ? Color.primary : Color.clear)
                        .overlay(Circle().strokeBorder(Color.secondary))
                        .frame(width: 14, height: 14)
                }
            }

            if let pinError = viewModel.pinError {
                Text(pinError == .wrongPin ? "Incorrect PIN. Try again." : String(describing: pinError))
                    .foregroundStyle(.red)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"], id: \.self) { key in
                    Button {
                        if key == "⌫" {
                            viewModel.deletePINDigit()
                        } else if !key.isEmpty {
                            viewModel.appendPINDigit(key)
                        }
                    } label: {
                        Text(key)
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(key.isEmpty)
                }
            }

            Button("Check balance") {
                Task { await viewModel.submitPIN() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmitPIN)

            Button("Back") { viewModel.backToChoice() }
                .buttonStyle(.borderless)

            Spacer()
        }
        .padding()
        .navigationTitle("Balance sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}
