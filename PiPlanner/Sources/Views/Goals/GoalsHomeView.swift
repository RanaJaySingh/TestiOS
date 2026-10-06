import SwiftUI
import SwiftData

struct GoalsHomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [Goal]
    @Query private var accounts: [Account]
    @Query private var settings: [UserSettings]
    
    @State private var showSyncSheet: Bool = false
    @State private var showNewGoalForm: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var selectedGoal: Goal?
    @State private var showPendingCreditBanner: Bool = false
    @State private var pendingAmount: Decimal = 0
    
    private var dedicatedAccount: Account? {
        accounts.first { $0.isDedicatedSavings }
    }
    
    private var userName: String {
        settings.first?.userName ?? "Rahul"
    }
    
    private var activeGoals: [Goal] {
        goals.filter { $0.isActive }
    }
    
    private var totalSaved: Decimal {
        activeGoals.reduce(0) { $0 + $1.savedAmount }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greetingSection
                
                if showPendingCreditBanner {
                    pendingCreditBanner
                }
                
                if let account = dedicatedAccount {
                    balanceSection(account: account)
                }
                
                quickActionsSection
                
                goalsSection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSyncSheet) {
            SyncSheetView(account: dedicatedAccount) { newAmount in
                pendingAmount = newAmount
                showPendingCreditBanner = true
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNewGoalForm) {
            NavigationStack {
                GoalFormScreen(
                    isInitialSetup: false,
                    onSave: { draft in
                        createGoal(from: draft)
                    }
                )
            }
        }
        .sheet(isPresented: $showTransferSheet) {
            NavigationStack {
                TransferView()
            }
        }
        .sheet(item: $selectedGoal) { goal in
            NavigationStack {
                GoalDetailView(goal: goal)
            }
        }
    }
    
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your savings are on track")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, 8)
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        return "\(greeting), \(userName)"
    }
    
    private var pendingCreditBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("New amount detected")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(pendingAmount.formattedINR) needs to be assigned")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Button("Assign") {
                appState.selectedTab = .history
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(Theme.primaryNavy)
        }
        .padding(Theme.cardPadding)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(Theme.cornerRadius)
    }
    
    @ViewBuilder
    private func balanceSection(account: Account) -> some View {
        BalanceCard(
            balance: totalSaved,
            accountName: account.shortDisplayName,
            lastSynced: account.lastSyncedAt,
            onSync: { showSyncSheet = true }
        )
    }
    
    private var quickActionsSection: some View {
        QuickActionsGrid(
            onSync: { showSyncSheet = true },
            onNewGoal: { showNewGoalForm = true },
            onTransfer: { showTransferSheet = true },
            onHistory: { appState.selectedTab = .history }
        )
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Goals")
                    .font(.headline)
                
                Spacer()
                
                if activeGoals.count > 3 {
                    Button("See all") {
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.primaryNavy)
                }
            }
            
            if activeGoals.isEmpty {
                emptyGoalsCard
            } else {
                ForEach(activeGoals.sorted { $0.creditSharePercent > $1.creditSharePercent }) { goal in
                    GoalCard(goal: goal) {
                        selectedGoal = goal
                    }
                }
            }
        }
    }
    
    private var emptyGoalsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(Theme.primaryNavy.opacity(0.5))
            
            Text("No goals yet")
                .font(.headline)
            
            Text("Create your first savings goal to get started")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            PrimaryButton(title: "Add a goal", action: { showNewGoalForm = true })
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func createGoal(from draft: GrokProposal.GoalDraft) {
        let existingPercents = activeGoals.map { $0.creditSharePercent }.reduce(0, +)
        let newPercent = max(0, 100 - existingPercents)
        
        let goal = Goal(
            name: draft.name,
            targetAmount: draft.targetAmount,
            startDate: Date(),
            endDate: draft.endDate,
            inflationRate: draft.inflationRate,
            creditSharePercent: newPercent,
            emoji: draft.emoji
        )
        
        modelContext.insert(goal)
        
        if newPercent < 100 && !activeGoals.isEmpty {
            var allGoals = activeGoals
            allGoals.append(goal)
            SplitEngine.shared.redistributePercents(goals: &allGoals)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        GoalsHomeView()
    }
    .environmentObject(AppState())
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
