import SwiftUI
import SwiftData

struct SetupFlowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query private var settings: [UserSettings]
    
    @State private var selectedAccountId: UUID?
    @State private var hasConsented: Bool = false
    @State private var isManualEntry: Bool = false
    @State private var manualBalance: Decimal = 0
    @State private var showUPIPin: Bool = false
    @State private var balanceFetched: Bool = false
    @State private var goalDrafts: [GrokProposal.GoalDraft] = []
    @State private var inflationRate: Double = 0.07
    @State private var goalPercents: [UUID: Int] = [:]
    
    var body: some View {
        NavigationStack {
            Group {
                switch appState.currentSetupStep {
                case .welcome:
                    WelcomeScreen(onContinue: {
                        initializeAccountsIfNeeded()
                        appState.advanceSetup()
                    })
                    
                case .accounts:
                    AccountsScreen(
                        accounts: accounts,
                        selectedAccountId: $selectedAccountId,
                        onContinue: {
                            markAccountAsDedicated()
                            appState.advanceSetup()
                        }
                    )
                    
                case .consent:
                    ConsentScreen(
                        accountName: selectedAccount?.shortDisplayName ?? "",
                        onYes: {
                            hasConsented = true
                            if let settings = settings.first {
                                settings.hasConsentedToAutoSync = true
                            }
                            appState.goToSetupStep(.balanceAuto)
                        },
                        onNo: {
                            hasConsented = false
                            isManualEntry = true
                            appState.goToSetupStep(.balanceManual)
                        }
                    )
                    
                case .balanceAuto:
                    BalanceAutoScreen(
                        balance: selectedAccount?.balance ?? 0,
                        accountName: selectedAccount?.shortDisplayName ?? "",
                        onContinue: {
                            if let account = selectedAccount {
                                account.lastSyncedAt = Date()
                            }
                            appState.goToSetupStep(.goalChat)
                        }
                    )
                    
                case .balanceManual:
                    BalanceManualScreen(
                        balance: $manualBalance,
                        showUPIPin: $showUPIPin,
                        account: selectedAccount,
                        onManualContinue: {
                            if let account = selectedAccount {
                                account.balance = manualBalance
                            }
                            appState.goToSetupStep(.goalChat)
                        },
                        onUPIPinComplete: { success in
                            showUPIPin = false
                            if success {
                                if let account = selectedAccount {
                                    account.lastSyncedAt = Date()
                                }
                                appState.goToSetupStep(.goalChat)
                            }
                        }
                    )
                    
                case .upiPin:
                    if let account = selectedAccount {
                        UPIPinScreen(
                            account: account,
                            onComplete: { success in
                                if success {
                                    account.lastSyncedAt = Date()
                                    appState.goToSetupStep(.goalChat)
                                }
                            },
                            onCancel: {
                                appState.goToSetupStep(.balanceManual)
                            }
                        )
                    }
                    
                case .goalChat:
                    GoalChatScreen(
                        currentBalance: selectedAccount?.balance ?? 0,
                        onGoalsCreated: { drafts in
                            goalDrafts = drafts
                            initializeGoalPercents()
                            appState.goToSetupStep(.inflation)
                        },
                        onUseForm: {
                            appState.goToSetupStep(.goalForm)
                        }
                    )
                    
                case .goalForm:
                    GoalFormScreen(
                        isInitialSetup: true,
                        onSave: { draft in
                            goalDrafts.append(draft)
                            initializeGoalPercents()
                            if goalDrafts.count >= 1 {
                                appState.goToSetupStep(.inflation)
                            }
                        },
                        onAddAnother: {
                        }
                    )
                    
                case .inflation:
                    InflationScreen(
                        inflationRate: $inflationRate,
                        goals: goalDrafts,
                        onContinue: {
                            appState.goToSetupStep(.openingSplit)
                        }
                    )
                    
                case .openingSplit:
                    OpeningSplitScreen(
                        goals: goalDrafts,
                        percents: $goalPercents,
                        currentBalance: selectedAccount?.balance ?? 0,
                        onLock: {
                            createGoalsAndHistory()
                            completeSetup()
                        }
                    )
                    
                case .complete:
                    EmptyView()
                }
            }
        }
    }
    
    private var selectedAccount: Account? {
        accounts.first { $0.id == selectedAccountId }
    }
    
    private func initializeAccountsIfNeeded() {
        if accounts.isEmpty {
            DemoDataService.shared.initializeDemoAccounts(in: modelContext)
        }
    }
    
    private func markAccountAsDedicated() {
        for account in accounts {
            account.isDedicatedSavings = (account.id == selectedAccountId)
        }
        try? modelContext.save()
    }
    
    private func initializeGoalPercents() {
        let count = goalDrafts.count
        guard count > 0 else { return }
        
        let equalShare = 100 / count
        let remainder = 100 % count
        
        for (index, draft) in goalDrafts.enumerated() {
            let id = UUID()
            goalPercents[id] = equalShare + (index < remainder ? 1 : 0)
        }
    }
    
    private func createGoalsAndHistory() {
        let balance = selectedAccount?.balance ?? 0
        var createdGoals: [Goal] = []
        
        for (index, draft) in goalDrafts.enumerated() {
            let percentKeys = Array(goalPercents.keys)
            let percent = index < percentKeys.count ? goalPercents[percentKeys[index]] ?? 0 : 0
            
            let goal = Goal(
                name: draft.name,
                targetAmount: draft.targetAmount,
                savedAmount: 0,
                startDate: Date(),
                endDate: draft.endDate,
                inflationRate: inflationRate,
                creditSharePercent: percent,
                emoji: draft.emoji
            )
            modelContext.insert(goal)
            createdGoals.append(goal)
        }
        
        let splits = SplitEngine.shared.calculateSplitAmounts(totalAmount: balance, goals: createdGoals)
        var goalSplits: [GoalSplit] = []
        
        for goal in createdGoals {
            let amount = splits[goal.id] ?? 0
            goal.savedAmount = amount
            goalSplits.append(GoalSplit(
                goalId: goal.id,
                goalName: goal.name,
                amount: amount,
                percent: goal.creditSharePercent
            ))
        }
        
        let openingEntry = HistoryEntry(
            type: .openingBalance,
            totalAmount: balance,
            splits: goalSplits,
            isLocked: true,
            balanceAfter: balance
        )
        modelContext.insert(openingEntry)
        
        try? modelContext.save()
    }
    
    private func completeSetup() {
        if let settings = settings.first {
            settings.hasCompletedSetup = true
            settings.defaultInflationRate = inflationRate
            settings.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

#Preview {
    SetupFlowView()
        .environmentObject(AppState())
        .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
