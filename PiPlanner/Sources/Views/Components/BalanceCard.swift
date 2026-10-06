import SwiftUI

struct BalanceCard: View {
    let balance: Decimal
    let accountName: String
    let lastSynced: Date?
    var onSync: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let lastSynced = lastSynced {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Balance read automatically")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    Text(balance.formattedINR)
                        .font(.system(size: 36, weight: .bold))
                    
                    Text(accountName)
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if let onSync = onSync {
                    Button(action: onSync) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(Theme.primaryNavy)
                    }
                }
            }
            
            if let lastSynced = lastSynced {
                HStack {
                    Text("Last synced \(DateFormatters.formatRelative(lastSynced))")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct BalanceFetchedCard: View {
    let balance: Decimal
    let accountName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Balance fetched")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            
            Text(balance.formattedINR)
                .font(.system(size: 42, weight: .bold))
            
            Text(accountName)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        BalanceCard(
            balance: 100000,
            accountName: "Savings · HDFC ••4821",
            lastSynced: Date(),
            onSync: {}
        )
        
        BalanceFetchedCard(
            balance: 100000,
            accountName: "HDFC ••4821"
        )
    }
    .padding()
    .background(Theme.background)
}
