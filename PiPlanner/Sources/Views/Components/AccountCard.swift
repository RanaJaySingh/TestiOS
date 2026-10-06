import SwiftUI

struct AccountCard: View {
    let account: Account
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.primaryNavy.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: account.accountType == .savings ? "building.columns" : "creditcard")
                        .foregroundColor(Theme.primaryNavy)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.balance.formattedINR)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(account.accountType.rawValue.capitalized) · \(account.bankName) ••\(account.lastFourDigits)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
            }
            
            if account.accountType == .savings {
                HStack {
                    Text("Dedicated savings")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .tint(Theme.primaryNavy)
                }
            } else {
                Text("Everyday spend. Not split across goals.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(isSelected ? Theme.primaryNavy : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        AccountCard(
            account: Account.demoSavings,
            isSelected: true,
            onToggle: { _ in }
        )
        AccountCard(
            account: Account.demoSpending,
            isSelected: false,
            onToggle: { _ in }
        )
    }
    .padding()
    .background(Theme.background)
}
