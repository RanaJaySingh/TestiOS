import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var userName: String
    var hasCompletedSetup: Bool
    var hasConsentedToAutoSync: Bool
    var defaultInflationRate: Double
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        userName: String = "Rahul",
        hasCompletedSetup: Bool = false,
        hasConsentedToAutoSync: Bool = false,
        defaultInflationRate: Double = 0.07,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userName = userName
        self.hasCompletedSetup = hasCompletedSetup
        self.hasConsentedToAutoSync = hasConsentedToAutoSync
        self.defaultInflationRate = defaultInflationRate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
