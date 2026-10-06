import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var name: String
    var targetAmount: Decimal
    var savedAmount: Decimal
    var startDate: Date
    var endDate: Date
    var inflationRate: Double
    var creditSharePercent: Int
    var pendingCreditSharePercent: Int?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var emoji: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        savedAmount: Decimal = 0,
        startDate: Date = Date(),
        endDate: Date,
        inflationRate: Double = 0.07,
        creditSharePercent: Int = 0,
        isActive: Bool = true,
        emoji: String? = nil
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.startDate = startDate
        self.endDate = endDate
        self.inflationRate = inflationRate
        self.creditSharePercent = creditSharePercent
        self.pendingCreditSharePercent = nil
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.emoji = emoji
    }
    
    var targetWithInflation: Decimal {
        let years = Double(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) / 365.0
        let inflationMultiplier = pow(1 + inflationRate, years)
        return targetAmount * Decimal(inflationMultiplier)
    }
    
    var progressPercent: Double {
        guard targetWithInflation > 0 else { return 0 }
        return min(1.0, Double(truncating: (savedAmount / targetWithInflation) as NSNumber))
    }
    
    var monthsRemaining: Int {
        let components = Calendar.current.dateComponents([.month], from: Date(), to: endDate)
        return max(0, components.month ?? 0)
    }
    
    var needsPerMonth: Decimal {
        guard monthsRemaining > 0 else { return 0 }
        let remaining = targetWithInflation - savedAmount
        return max(0, remaining / Decimal(monthsRemaining))
    }
    
    var status: GoalStatus {
        let expectedProgress = expectedProgressPercent
        let actual = progressPercent
        
        if actual >= expectedProgress * 0.9 {
            return .onTrack
        } else {
            return .behind
        }
    }
    
    private var expectedProgressPercent: Double {
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let elapsedDays = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return Double(elapsedDays) / Double(totalDays)
    }
    
    enum GoalStatus: String {
        case onTrack = "On track"
        case behind = "Behind"
        
        var color: String {
            switch self {
            case .onTrack: return "green"
            case .behind: return "amber"
            }
        }
    }
}

extension Goal {
    static var demoCar: Goal {
        Goal(
            name: "Car",
            targetAmount: 500000,
            savedAmount: 85000,
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
            creditSharePercent: 60,
            emoji: "🚗"
        )
    }
    
    static var demoEmergency: Goal {
        Goal(
            name: "Emergency",
            targetAmount: 200000,
            savedAmount: 55000,
            startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
            creditSharePercent: 40,
            emoji: "🏥"
        )
    }
}
