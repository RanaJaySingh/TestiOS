import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var bankName: String
    var accountType: AccountType
    var lastFourDigits: String
    var balance: Decimal
    var isDedicatedSavings: Bool
    var lastSyncedAt: Date?
    var createdAt: Date
    
    enum AccountType: String, Codable {
        case savings
        case spending
    }
    
    init(
        id: UUID = UUID(),
        bankName: String,
        accountType: AccountType,
        lastFourDigits: String,
        balance: Decimal,
        isDedicatedSavings: Bool = false,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bankName = bankName
        self.accountType = accountType
        self.lastFourDigits = lastFourDigits
        self.balance = balance
        self.isDedicatedSavings = isDedicatedSavings
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
    }
    
    var displayName: String {
        "\(accountType.rawValue.capitalized) · \(bankName) ••\(lastFourDigits)"
    }
    
    var shortDisplayName: String {
        "\(bankName) ••\(lastFourDigits)"
    }
}

extension Account {
    static var demoSavings: Account {
        Account(
            bankName: "HDFC",
            accountType: .savings,
            lastFourDigits: "4821",
            balance: 100000,
            isDedicatedSavings: true
        )
    }
    
    static var demoSpending: Account {
        Account(
            bankName: "SBI",
            accountType: .spending,
            lastFourDigits: "7730",
            balance: 72000,
            isDedicatedSavings: false
        )
    }
}
