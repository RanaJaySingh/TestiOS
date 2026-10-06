import SwiftUI

struct WelcomeScreen: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 40)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Theme.primaryNavy)
                                .frame(height: 200)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("here: illustration: goals")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PIPLANNER")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primaryNavy)
                                .tracking(1.5)
                            
                            Text("Every Rupee Has a Plan.")
                                .font(.system(size: 28, weight: .bold))
                            
                            Text("Every credit to savings gets a goal before it can be spent.")
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack {
                                Text("Powered by Grok")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, Theme.screenPadding)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How it works")
                            .font(.headline)
                            .padding(.horizontal, Theme.screenPadding)
                        
                        VStack(spacing: 16) {
                            HowItWorksStep(
                                number: 1,
                                icon: "building.columns",
                                title: "Pick a savings account",
                                description: "Your dedicated savings, not your spending."
                            )
                            
                            HowItWorksStep(
                                number: 2,
                                icon: "target",
                                title: "Set your goals",
                                description: "Car, emergency fund, trip — split across goals."
                            )
                            
                            HowItWorksStep(
                                number: 3,
                                icon: "arrow.down.circle",
                                title: "Split every new credit",
                                description: "Saved amounts lock. Only transfers or withdrawals move funds."
                            )
                        }
                        .padding(.horizontal, Theme.screenPadding)
                    }
                }
                .padding(.bottom, 100)
            }
            
            VStack {
                PrimaryButton(
                    title: "Set up savings",
                    action: onContinue,
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
                    Image(systemName: "arrow.left")
                        .opacity(0)
                    Spacer()
                    Text("PiPlanner")
                        .font(.headline)
                    Spacer()
                }
            }
        }
    }
}

struct HowItWorksStep: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.primaryNavy)
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundColor(Theme.primaryNavy)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WelcomeScreen(onContinue: {})
    }
}
