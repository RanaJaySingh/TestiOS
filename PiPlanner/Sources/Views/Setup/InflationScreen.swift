import SwiftUI

struct InflationScreen: View {
    @Binding var inflationRate: Double
    let goals: [GrokProposal.GoalDraft]
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Inflation adjustment")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("We'll adjust your targets to account for rising prices.")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("\(Int(inflationRate * 100))%")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(Theme.primaryNavy)
                            
                            Text("per year")
                                .font(.headline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        HStack(spacing: 16) {
                            Button(action: { if inflationRate > 0.01 { inflationRate -= 0.01 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.primaryNavy)
                            }
                            
                            Slider(value: $inflationRate, in: 0...0.15, step: 0.01)
                                .tint(Theme.primaryNavy)
                            
                            Button(action: { if inflationRate < 0.15 { inflationRate += 0.01 } }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.primaryNavy)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your adjusted targets")
                            .font(.headline)
                        
                        ForEach(goals, id: \.name) { goal in
                            InflationGoalRow(goal: goal, inflationRate: inflationRate)
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    
                    Text("India's average inflation is 5-7%. Higher rates mean bigger adjusted targets.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 100)
            }
            
            VStack {
                PrimaryButton(title: "Continue", action: onContinue, showArrow: true)
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Inflation")
    }
}

struct InflationGoalRow: View {
    let goal: GrokProposal.GoalDraft
    let inflationRate: Double
    
    var body: some View {
        HStack {
            if let emoji = goal.emoji {
                Text(emoji)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Original: \(goal.targetAmount.formattedINR)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(adjustedTarget.formattedINR)
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                if adjustedTarget > goal.targetAmount {
                    Text("+\(increase.formattedINR)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var adjustedTarget: Decimal {
        let years = Double(Calendar.current.dateComponents([.day], from: Date(), to: goal.endDate).day ?? 0) / 365.0
        let inflationMultiplier = pow(1 + inflationRate, years)
        return goal.targetAmount * Decimal(inflationMultiplier)
    }
    
    private var increase: Decimal {
        adjustedTarget - goal.targetAmount
    }
}

#Preview {
    NavigationStack {
        InflationScreen(
            inflationRate: .constant(0.07),
            goals: [
                .init(name: "Car", targetAmount: 500000, endDate: Calendar.current.date(byAdding: .year, value: 2, to: Date())!, emoji: "🚗"),
                .init(name: "Emergency", targetAmount: 200000, endDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!, emoji: "🏥")
            ],
            onContinue: {}
        )
    }
}
