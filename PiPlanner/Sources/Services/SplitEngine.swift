import Foundation
import SwiftData

@MainActor
class SplitEngine {
    static let shared = SplitEngine()
    
    func validateSplits(_ percents: [Int]) -> SplitValidation {
        let total = percents.reduce(0, +)
        
        if total == 100 {
            return .valid
        } else if total < 100 {
            return .underAllocated(remaining: 100 - total)
        } else {
            return .overAllocated(excess: total - 100)
        }
    }
    
    func calculateSplitAmounts(totalAmount: Decimal, goals: [Goal]) -> [UUID: Decimal] {
        var splits: [UUID: Decimal] = [:]
        var remaining = totalAmount
        
        let sortedGoals = goals.sorted { $0.creditSharePercent > $1.creditSharePercent }
        
        for (index, goal) in sortedGoals.enumerated() {
            if index == sortedGoals.count - 1 {
                splits[goal.id] = remaining
            } else {
                let amount = (totalAmount * Decimal(goal.creditSharePercent)) / 100
                let roundedAmount = roundToNearestRupee(amount)
                splits[goal.id] = roundedAmount
                remaining -= roundedAmount
            }
        }
        
        return splits
    }
    
    func applySplit(amount: Decimal, to goals: [Goal], context: ModelContext) -> HistoryEntry {
        let splits = calculateSplitAmounts(totalAmount: amount, goals: goals)
        
        var goalSplits: [GoalSplit] = []
        
        for goal in goals {
            let splitAmount = splits[goal.id] ?? 0
            goal.savedAmount += splitAmount
            goal.updatedAt = Date()
            
            goalSplits.append(GoalSplit(
                goalId: goal.id,
                goalName: goal.name,
                amount: splitAmount,
                percent: goal.creditSharePercent
            ))
        }
        
        let entry = HistoryEntry(
            type: .newCredit,
            totalAmount: amount,
            splits: goalSplits,
            isLocked: true
        )
        
        context.insert(entry)
        try? context.save()
        
        return entry
    }
    
    func redistributePercents(goals: inout [Goal], excludingGoalId: UUID? = nil) {
        let activeGoals = goals.filter { $0.id != excludingGoalId && $0.isActive }
        guard !activeGoals.isEmpty else { return }
        
        let equalShare = 100 / activeGoals.count
        let remainder = 100 % activeGoals.count
        
        for (index, goal) in activeGoals.enumerated() {
            if let goalIndex = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[goalIndex].creditSharePercent = equalShare + (index < remainder ? 1 : 0)
            }
        }
    }
    
    private func roundToNearestRupee(_ amount: Decimal) -> Decimal {
        let behavior = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        
        let number = NSDecimalNumber(decimal: amount)
        return number.rounding(accordingToBehavior: behavior).decimalValue
    }
    
    enum SplitValidation: Equatable {
        case valid
        case underAllocated(remaining: Int)
        case overAllocated(excess: Int)
        
        var isValid: Bool {
            self == .valid
        }
    }
}
