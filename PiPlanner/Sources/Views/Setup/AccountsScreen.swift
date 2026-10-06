import SwiftUI

struct AccountsScreen: View {
    let accounts: [Account]
    @Binding var selectedAccountId: UUID?
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your accounts")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Pick one for dedicated savings.")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 16)
                    
                    VStack(spacing: 16) {
                        ForEach(accounts, id: \.id) { account in
                            AccountCard(
                                account: account,
                                isSelected: account.id == selectedAccountId,
                                onToggle: { isOn in
                                    if isOn {
                                        selectedAccountId = account.id
                                    } else if account.id == selectedAccountId {
                                        selectedAccountId = nil
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 100)
            }
            
            VStack {
                PrimaryButton(
                    title: "Continue",
                    action: onContinue,
                    isDisabled: selectedAccountId == nil,
                    showArrow: true
                )
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text("Accounts")
                        .font(.headline)
                    Spacer()
                    StepIndicator(currentStep: 1, totalSteps: 3)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountsScreen(
            accounts: [Account.demoSavings, Account.demoSpending],
            selectedAccountId: .constant(nil),
            onContinue: {}
        )
    }
}
