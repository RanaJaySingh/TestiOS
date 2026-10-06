import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Bindable var goal: Goal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var historyEntries: [HistoryEntry]
    
    @State private var showEditForm: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showTransfer: Bool = false
    
    private var relatedHistory: [HistoryEntry] {
        historyEntries
            .filter { entry in
                entry.splits.contains { $0.goalId == goal.id }
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressSection
                
                statsSection
                
                if !relatedHistory.isEmpty {
                    historySection
                }
                
                actionsSection
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditForm = true
                }
                .foregroundColor(Theme.primaryNavy)
            }
        }
        .sheet(isPresented: $showEditForm) {
            NavigationStack {
                GoalFormScreen(
                    existingGoal: goal,
                    onSave: { draft in
                        updateGoal(with: draft)
                    },
                    onDelete: {
                        showDeleteConfirmation = true
                    }
                )
            }
        }
        .sheet(isPresented: $showTransfer) {
            NavigationStack {
                TransferView(preselectedFrom: goal)
            }
        }
        .alert("Delete goal?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("The saved amount (\(goal.savedAmount.formattedINR)) will be released and split equally among remaining goals.")
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                
                Circle()
                    .trim(from: 0, to: CGFloat(goal.progressPercent))
                    .stroke(Theme.primaryNavy, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    if let emoji = goal.emoji {
                        Text(emoji)
                            .font(.system(size: 32))
                    }
                    
                    Text("\(Int(goal.progressPercent * 100))%")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("complete")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(width: 150, height: 150)
            
            VStack(spacing: 4) {
                Text(goal.savedAmount.formattedINR)
                    .font(.system(size: 28, weight: .bold))
                
                Text("of \(goal.targetWithInflation.formattedINR)")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            
            StatusBadge(status: goal.status)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            StatRow(label: "Target", value: goal.targetAmount.formattedINR)
            StatRow(label: "With inflation (\(Int(goal.inflationRate * 100))%)", value: goal.targetWithInflation.formattedINR)
            StatRow(label: "Needs/month", value: goal.needsPerMonth.formattedINR)
            StatRow(label: "Credit share", value: "\(goal.creditSharePercent)%")
            StatRow(label: "Start date", value: goal.startDate.dayMonthYearString)
            StatRow(label: "End date", value: goal.endDate.dayMonthYearString)
            StatRow(label: "Months remaining", value: "\(goal.monthsRemaining)")
            
            if let pendingPercent = goal.pendingCreditSharePercent {
                HStack {
                    Text("Pending share change")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(pendingPercent)% (applies next credit)")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From History")
                .font(.headline)
            
            ForEach(relatedHistory) { entry in
                HistoryRow(entry: entry)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            SecondaryButton(title: "Transfer from this goal", action: { showTransfer = true })
            
            Button(action: { showDeleteConfirmation = true }) {
                Text("Delete goal")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func updateGoal(with draft: GrokProposal.GoalDraft) {
        goal.name = draft.name
        goal.targetAmount = draft.targetAmount
        goal.endDate = draft.endDate
        goal.inflationRate = draft.inflationRate
        goal.emoji = draft.emoji
        goal.updatedAt = Date()
        
        try? modelContext.save()
    }
    
    private func deleteGoal() {
        goal.isActive = false
        
        let entry = HistoryEntry(
            type: .goalDeleted,
            totalAmount: goal.savedAmount,
            splits: [GoalSplit(
                goalId: goal.id,
                goalName: goal.name,
                amount: goal.savedAmount,
                percent: goal.creditSharePercent
            )],
            note: "Released from \(goal.name)",
            isLocked: true
        )
        
        modelContext.insert(entry)
        try? modelContext.save()
        
        dismiss()
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal.demoCar)
    }
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
