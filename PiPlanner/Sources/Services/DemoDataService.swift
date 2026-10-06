import Foundation
import SwiftData

@MainActor
class DemoDataService {
    static let shared = DemoDataService()
    
    let demoSavingsBalance: Decimal = 100000
    let demoSpendingBalance: Decimal = 72000
    let demoPIN = "1234"
    
    func initializeDemoAccounts(in context: ModelContext) {
        let savings = Account(
            bankName: "HDFC",
            accountType: .savings,
            lastFourDigits: "4821",
            balance: demoSavingsBalance,
            isDedicatedSavings: false
        )
        
        let spending = Account(
            bankName: "SBI",
            accountType: .spending,
            lastFourDigits: "7730",
            balance: demoSpendingBalance,
            isDedicatedSavings: false
        )
        
        context.insert(savings)
        context.insert(spending)
        try? context.save()
    }
    
    func validateUPIPin(_ pin: String) -> Bool {
        return pin == demoPIN
    }
    
    func fetchBalance(for account: Account) -> Decimal {
        return account.balance
    }
    
    func simulateNewCredit(amount: Decimal = 25000, to account: inout Account) {
        account.balance += amount
        account.lastSyncedAt = Date()
    }
    
    func resetDemo(context: ModelContext) {
        do {
            try context.delete(model: Account.self)
            try context.delete(model: Goal.self)
            try context.delete(model: HistoryEntry.self)
            try context.delete(model: UserSettings.self)
            try context.save()
            
            let settings = UserSettings()
            context.insert(settings)
            initializeDemoAccounts(in: context)
            try context.save()
        } catch {
            print("Error resetting demo: \(error)")
        }
    }
}
