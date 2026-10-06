import SwiftUI

struct BalanceAutoScreen: View {
    let balance: Decimal
    let accountName: String
    let onContinue: () -> Void
    
    @State private var showBalance = false
    @State private var animatedBalance: Decimal = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                BalanceFetchedCard(
                    balance: showBalance ? balance : 0,
                    accountName: accountName
                )
                .opacity(showBalance ? 1 : 0)
                .scaleEffect(showBalance ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showBalance)
            }
            .padding(.horizontal, Theme.screenPadding)
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.primaryNavy)
                    Text("Grok chat")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                PrimaryButton(title: "Continue", action: onContinue, showArrow: true)
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text("Balance")
                        .font(.headline)
                    Spacer()
                    StepIndicator(currentStep: 2, totalSteps: 3)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showBalance = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BalanceAutoScreen(
            balance: 100000,
            accountName: "HDFC ••4821",
            onContinue: {}
        )
    }
}
