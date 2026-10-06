import Foundation
import SwiftData

@Model
final class HistoryEntry {
    var id: UUID
    var type: EntryType
    var totalAmount: Decimal
    var splits: [GoalSplit]
    var note: String?
    var isLocked: Bool
    var createdAt: Date
    var balanceAfter: Decimal?
    
    enum EntryType: String, Codable {
        case openingBalance = "Opening balance"
        case newCredit = "New credit"
        case customSplit = "Custom split"
        case typed = "Typed"
        case transfer = "Transfer"
        case withdrawal = "Withdrawal"
        case goalDeleted = "Goal deleted"
    }
    
    init(
        id: UUID = UUID(),
        type: EntryType,
        totalAmount: Decimal,
        splits: [GoalSplit] = [],
        note: String? = nil,
        isLocked: Bool = false,
        createdAt: Date = Date(),
        balanceAfter: Decimal? = nil
    ) {
        self.id = id
        self.type = type
        self.totalAmount = totalAmount
        self.splits = splits
        self.note = note
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.balanceAfter = balanceAfter
    }
}

struct GoalSplit: Codable, Hashable {
    var goalId: UUID
    var goalName: String
    var amount: Decimal
    var percent: Int
}

extension HistoryEntry {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: createdAt)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }
    
    var icon: String {
        switch type {
        case .openingBalance: return "banknote"
        case .newCredit: return "arrow.down.circle"
        case .customSplit: return "chart.pie"
        case .typed: return "keyboard"
        case .transfer: return "arrow.left.arrow.right"
        case .withdrawal: return "arrow.up.circle"
        case .goalDeleted: return "trash"
        }
    }
}
