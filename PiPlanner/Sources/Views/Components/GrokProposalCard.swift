import SwiftUI

struct GrokProposalCard: View {
    let proposal: GrokProposal
    let onEdit: () -> Void
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.primaryNavy)
                Text("Grok's proposal")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(proposal.goals, id: \.name) { goal in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(goal.targetAmount.formattedINR)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("by \(goal.endDate.monthYearString)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, 4)
            }
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .foregroundColor(Theme.primaryNavy)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.primaryNavy, lineWidth: 1)
                        )
                }
                
                Button(action: onConfirm) {
                    Text("Confirm")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.primaryNavy)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            
            Text("Created by PiPlanner. Estimate.")
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .stroke(Theme.primaryNavy.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GrokProposal {
    struct GoalDraft {
        var name: String
        var targetAmount: Decimal
        var endDate: Date
        var inflationRate: Double = 0.07
        var emoji: String?
    }
    
    var goals: [GoalDraft]
    var message: String?
}

#Preview {
    GrokProposalCard(
        proposal: GrokProposal(
            goals: [
                .init(name: "Car", targetAmount: 500000, endDate: Calendar.current.date(byAdding: .year, value: 2, to: Date())!, emoji: "🚗"),
                .init(name: "Emergency", targetAmount: 200000, endDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!, emoji: "🏥")
            ],
            message: "Based on your goals..."
        ),
        onEdit: {},
        onConfirm: {}
    )
    .padding()
    .background(Theme.background)
}
