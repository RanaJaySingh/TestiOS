import SwiftUI

struct UPIPinScreen: View {
    let account: Account
    let onComplete: (Bool) -> Void
    let onCancel: () -> Void
    
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                if showError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("Wrong PIN")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        PrimaryButton(title: "Try again", action: {
                            showError = false
                        })
                        .padding(.top, 16)
                        
                        SecondaryButton(title: "Enter manually", action: onCancel)
                    }
                    .padding(Theme.screenPadding)
                } else if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Checking balance...")
                            .font(.headline)
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    UPIPinPad(
                        bankName: account.bankName,
                        lastFourDigits: account.lastFourDigits,
                        onComplete: { pin in
                            validatePin(pin)
                        },
                        onCancel: onCancel
                    )
                }
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }
    
    private func validatePin(_ pin: String) {
        isProcessing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
            
            if DemoDataService.shared.validateUPIPin(pin) {
                onComplete(true)
            } else {
                errorMessage = "The PIN you entered was incorrect. Please try again or enter the balance manually."
                showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        UPIPinScreen(
            account: Account.demoSavings,
            onComplete: { _ in },
            onCancel: {}
        )
    }
}
