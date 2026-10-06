import SwiftUI

struct PercentInput: View {
    let goalName: String
    let emoji: String?
    @Binding var percent: Int
    var needsPerMonth: Decimal?
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.title3)
                }
                
                Text(goalName)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { if percent > 0 { percent -= 5 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(isDisabled ? .gray : Theme.primaryNavy)
                    }
                    .disabled(isDisabled || percent <= 0)
                    
                    Text("\(percent)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(minWidth: 50)
                    
                    Button(action: { if percent < 100 { percent += 5 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(isDisabled ? .gray : Theme.primaryNavy)
                    }
                    .disabled(isDisabled || percent >= 100)
                }
            }
            
            if let needs = needsPerMonth {
                HStack {
                    Text("needs \(needs.formattedINR)/month")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

struct TotalPercentValidation: View {
    let totalPercent: Int
    
    var body: some View {
        HStack {
            Text("Total \(totalPercent)%")
                .font(.headline)
                .fontWeight(.bold)
            
            Spacer()
            
            if totalPercent == 100 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if totalPercent > 100 {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .foregroundColor(totalPercent == 100 ? .green : (totalPercent > 100 ? .red : Theme.textSecondary))
    }
}

#Preview {
    VStack(spacing: 16) {
        PercentInput(
            goalName: "Car",
            emoji: "🚗",
            percent: .constant(60),
            needsPerMonth: 15000
        )
        
        PercentInput(
            goalName: "Emergency",
            emoji: "🏥",
            percent: .constant(40),
            needsPerMonth: 8000
        )
        
        TotalPercentValidation(totalPercent: 100)
    }
    .padding()
    .background(Theme.background)
}
