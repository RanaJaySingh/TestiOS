import SwiftUI
import SwiftData

struct SyncSheetView: View {
    let account: Account?
    let onNewAmount: (Decimal) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var isChecking: Bool = false
    @State private var newBalance: Decimal?
    @State private var showUPIPin: Bool = false
    @State private var balanceResult: BalanceResult?
    
    enum BalanceResult {
        case same
        case increased(Decimal)
        case decreased(Decimal)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isChecking {
                    checkingView
                } else if let result = balanceResult {
                    resultView(result: result)
                } else {
                    initialView
                }
            }
            .padding(Theme.screenPadding)
            .navigationTitle("Sync balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var checkingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Checking balance...")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var initialView: some View {
        VStack(spacing: 24) {
            if let account = account {
                VStack(spacing: 8) {
                    Text("Current balance")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(account.balance.formattedINR)
                        .font(.system(size: 36, weight: .bold))
                    
                    if let lastSynced = account.lastSyncedAt {
                        Text("Last synced \(DateFormatters.formatRelative(lastSynced))")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(Theme.cardPadding)
                .frame(maxWidth: .infinity)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
            }
            
            VStack(spacing: 12) {
                PrimaryButton(title: "Check with UPI PIN", action: {
                    simulateBalanceCheck()
                })
                
                SecondaryButton(title: "Enter manually", action: {
                })
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func resultView(result: BalanceResult) -> some View {
        VStack(spacing: 24) {
            switch result {
            case .same:
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Balance unchanged")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("No new credits or debits detected")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                }
                
            case .increased(let amount):
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("New credit detected!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("+\(amount.formattedINR)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("Assign this amount to your goals")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                    
                    PrimaryButton(title: "Assign now", action: {
                        onNewAmount(amount)
                        dismiss()
                    })
                }
                
            case .decreased(let amount):
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    
                    Text("Balance went down")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("-\(amount.formattedINR)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("Record this as a withdrawal")
                        .font(.body)
                        .foregroundColor(Theme.textSecondary)
                    
                    PrimaryButton(title: "Record withdrawal", action: {
                        dismiss()
                    })
                }
            }
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    private func simulateBalanceCheck() {
        isChecking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isChecking = false
            
            let scenarios: [BalanceResult] = [
                .same,
                .increased(25000),
                .increased(15000)
            ]
            balanceResult = scenarios.randomElement() ?? .same
            
            if case .increased(let amount) = balanceResult, let account = account {
                account.balance += amount
                account.lastSyncedAt = Date()
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    SyncSheetView(account: Account.demoSavings, onNewAmount: { _ in })
}
