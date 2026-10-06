import SwiftUI

struct HistoryRow: View {
    let entry: HistoryEntry
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryNavy.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: entry.icon)
                        .foregroundColor(Theme.primaryNavy)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                        
                        if !entry.splits.isEmpty {
                            Text("· \(splitsSummary)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(amountText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(amountColor)
                    
                    if entry.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    
    private var splitsSummary: String {
        entry.splits.map { $0.goalName }.joined(separator: ", ")
    }
    
    private var amountText: String {
        switch entry.type {
        case .withdrawal:
            return "-\(entry.totalAmount.formattedINR)"
        case .transfer:
            return entry.totalAmount.formattedINR
        default:
            return "+\(entry.totalAmount.formattedINR)"
        }
    }
    
    private var amountColor: Color {
        switch entry.type {
        case .withdrawal:
            return .red
        case .transfer:
            return Theme.primaryNavy
        default:
            return .green
        }
    }
}

#Preview {
    VStack {
        HistoryRow(
            entry: HistoryEntry(
                type: .newCredit,
                totalAmount: 25000,
                splits: [
                    GoalSplit(goalId: UUID(), goalName: "Car", amount: 15000, percent: 60),
                    GoalSplit(goalId: UUID(), goalName: "Emergency", amount: 10000, percent: 40)
                ],
                isLocked: true
            )
        )
        
        HistoryRow(
            entry: HistoryEntry(
                type: .openingBalance,
                totalAmount: 100000,
                isLocked: true
            )
        )
        
        HistoryRow(
            entry: HistoryEntry(
                type: .withdrawal,
                totalAmount: 8000
            )
        )
    }
    .padding()
}
