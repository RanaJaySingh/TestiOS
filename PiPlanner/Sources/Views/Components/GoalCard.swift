import SwiftUI

struct GoalCard: View {
    let goal: Goal
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let emoji = goal.emoji {
                        Text(emoji)
                            .font(.title2)
                    }
                    
                    Text(goal.name)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    StatusBadge(status: goal.status)
                }
                
                ProgressBar(progress: goal.progressPercent)
                
                HStack {
                    Text("\(goal.savedAmount.formattedINR) of \(goal.targetWithInflation.formattedINR)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text("\(Int(goal.progressPercent * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Needs/month")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(goal.needsPerMonth.formattedINR)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("% of credits")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(goal.creditSharePercent)%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(Theme.cardPadding)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StatusBadge: View {
    let status: Goal.GoalStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .onTrack: return Color.green.opacity(0.15)
        case .behind: return Color.orange.opacity(0.15)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .onTrack: return .green
        case .behind: return .orange
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 8
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var foregroundColor: Color = Theme.primaryNavy
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(foregroundColor)
                    .frame(width: geometry.size.width * CGFloat(progress), height: height)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    VStack(spacing: 16) {
        GoalCard(goal: Goal.demoCar)
        GoalCard(goal: Goal.demoEmergency)
    }
    .padding()
    .background(Theme.background)
}
