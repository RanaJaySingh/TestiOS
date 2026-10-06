import SwiftUI

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Theme.primaryNavy)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }
}

struct QuickActionsGrid: View {
    let onSync: () -> Void
    let onNewGoal: () -> Void
    let onTransfer: () -> Void
    let onHistory: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "arrow.clockwise", title: "Sync", action: onSync)
            QuickActionButton(icon: "plus", title: "New goal", action: onNewGoal)
            QuickActionButton(icon: "arrow.left.arrow.right", title: "Transfer", action: onTransfer)
            QuickActionButton(icon: "clock", title: "History", action: onHistory)
        }
    }
}

#Preview {
    QuickActionsGrid(
        onSync: {},
        onNewGoal: {},
        onTransfer: {},
        onHistory: {}
    )
    .padding()
    .background(Theme.background)
}
