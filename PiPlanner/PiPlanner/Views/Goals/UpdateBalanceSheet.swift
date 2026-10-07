import SwiftUI

/// Goals-tab Update balance stub (Consent Off, frame 9c).
/// Distinct from setup `UpdateBalanceSheet` in ConsentSheet.swift (frame 4).
struct GoalsUpdateBalanceSheet: View {
    let currentFormatted: String
    var onApply: (Paisa) -> Void
    var onDismiss: () -> Void

    @State private var digits = ""

    private var paisa: Paisa {
        ConsentService.paisa(fromRupeeDigits: digits)
    }

    private var canApply: Bool {
        ConsentService.canContinueManual(amountPaisa: paisa)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Current: \(currentFormatted)")
                        .foregroundStyle(.secondary)
                    TextField("New balance (₹)", text: $digits)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("updateBalance.digits")
                } footer: {
                    Text("Typed balances open the credit-assignment flow in a later ticket. This stub updates the dedicated account balance only.")
                }
            }
            .navigationTitle("Update balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(paisa)
                    }
                    .disabled(!canApply)
                    .accessibilityIdentifier("updateBalance.apply")
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("goals.updateBalanceSheet")
    }
}

#Preview {
    GoalsUpdateBalanceSheet(currentFormatted: "₹1,00,000", onApply: { _ in }, onDismiss: {})
}
