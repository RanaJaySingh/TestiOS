import SwiftUI

struct BalanceManualScreen: View {
    @Binding var balance: Decimal
    @Binding var showUPIPin: Bool
    let account: Account?
    let onManualContinue: () -> Void
    let onUPIPinComplete: (Bool) -> Void
    
    @State private var balanceText: String = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How much is in this account?")
                                .font(.system(size: 24, weight: .bold))
                        }
                        .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center) {
                                Text("₹")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $balanceText)
                                    .font(.system(size: 36, weight: .bold))
                                    .keyboardType(.numberPad)
                                    .onChange(of: balanceText) { _, newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        balanceText = filtered
                                        balance = Decimal(string: filtered) ?? 0
                                    }
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                        }
                        
                        UpdateBalanceSheet(
                            onManually: {},
                            onBalanceSync: {
                                showUPIPin = true
                            }
                        )
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 100)
                }
                
                VStack {
                    PrimaryButton(
                        title: "Continue",
                        action: onManualContinue,
                        isDisabled: balance <= 0,
                        showArrow: true
                    )
                }
                .padding(Theme.screenPadding)
                .background(Theme.background)
            }
            .background(Theme.background)
            
            if showUPIPin, let account = account {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showUPIPin = false
                    }
                
                UPIPinPad(
                    bankName: account.bankName,
                    lastFourDigits: account.lastFourDigits,
                    onComplete: { pin in
                        let isValid = DemoDataService.shared.validateUPIPin(pin)
                        onUPIPinComplete(isValid)
                    },
                    onCancel: {
                        showUPIPin = false
                    }
                )
                .padding(Theme.screenPadding)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text("Opening balance")
                        .font(.headline)
                    Spacer()
                    StepIndicator(currentStep: 2, totalSteps: 3)
                }
            }
        }
    }
}

struct UpdateBalanceSheet: View {
    let onManually: () -> Void
    let onBalanceSync: () -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text("Update balance")
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .foregroundColor(Theme.textPrimary)
            
            if isExpanded {
                VStack(spacing: 12) {
                    UpdateOptionRow(
                        icon: "pencil",
                        title: "Manually",
                        subtitle: "Type the amount yourself",
                        action: onManually
                    )
                    
                    UpdateOptionRow(
                        icon: "arrow.clockwise",
                        title: "Balance sync",
                        subtitle: "Check with your UPI PIN",
                        action: onBalanceSync
                    )
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

struct UpdateOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryNavy.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundColor(Theme.primaryNavy)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BalanceManualScreen(
            balance: .constant(0),
            showUPIPin: .constant(false),
            account: Account.demoSavings,
            onManualContinue: {},
            onUPIPinComplete: { _ in }
        )
    }
}
