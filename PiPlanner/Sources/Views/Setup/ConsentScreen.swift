import SwiftUI

struct ConsentScreen: View {
    let accountName: String
    let onYes: () -> Void
    let onNo: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.primaryNavy.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Text("Accounts")
                            .font(.caption)
                            .foregroundColor(Theme.primaryNavy)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Allow PiPlanner to check this balance?")
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Savings · \(accountName)")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    ConsentRow(icon: "checkmark", text: "Reads only this balance", isAllowed: true)
                    ConsentRow(icon: "checkmark", text: "Stores the last balance to find what is new", isAllowed: true)
                    ConsentRow(icon: "xmark", text: "Never sends statements, payees, UPI ids or OTPs", isAllowed: false)
                    ConsentRow(icon: "xmark", text: "Accounts transferred to Grok", isAllowed: false)
                    ConsentRow(icon: "gearshape", text: "Change it any time in Settings", isInfo: true)
                }
                .padding(Theme.cardPadding)
                .background(Theme.cardBackground)
                .cornerRadius(Theme.cornerRadius)
                
                VStack(spacing: 12) {
                    PrimaryButton(title: "Yes, update automatically", action: onYes)
                    SecondaryButton(title: "No, I'll update it myself", action: onNo)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            
            Spacer()
        }
        .background(Theme.background)
    }
}

struct ConsentRow: View {
    let icon: String
    let text: String
    var isAllowed: Bool = false
    var isInfo: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(isInfo ? Theme.textSecondary : (isAllowed ? .green : .red))
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
        }
    }
}

#Preview {
    ConsentScreen(
        accountName: "HDFC ••4821",
        onYes: {},
        onNo: {}
    )
}
