import SwiftUI
import SwiftData

struct AssignCreditView: View {
    let creditAmount: Decimal
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [Goal]
    
    @State private var useStandingSplit: Bool = true
    @State private var customPercents: [UUID: Int] = [:]
    @State private var showUpdatePercents: Bool = false
    @State private var showConfirmation: Bool = false
    
    private var activeGoals: [Goal] {
        goals.filter { $0.isActive }
    }
    
    private var totalPercent: Int {
        if useStandingSplit {
            return activeGoals.map { $0.creditSharePercent }.reduce(0, +)
        }
        return customPercents.values.reduce(0, +)
    }
    
    private var isValid: Bool {
        totalPercent == 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New credit detected")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("+\(creditAmount.formattedINR)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Use standing split")
                                .font(.headline)
                            
                            Spacer()
                            
                            Toggle("", isOn: $useStandingSplit)
                                .labelsHidden()
                                .tint(Theme.primaryNavy)
                        }
                        
                        if useStandingSplit {
                            ForEach(activeGoals) { goal in
                                StandingSplitRow(
                                    goal: goal,
                                    amount: splitAmount(for: goal)
                                )
                            }
                        } else {
                            ForEach(activeGoals) { goal in
                                CustomSplitRow(
                                    goal: goal,
                                    percent: Binding(
                                        get: { customPercents[goal.id] ?? goal.creditSharePercent },
                                        set: { customPercents[goal.id] = $0 }
                                    ),
                                    amount: customSplitAmount(for: goal)
                                )
                            }
                            
                            TotalPercentValidation(totalPercent: totalPercent)
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    
                    if !useStandingSplit {
                        Toggle(isOn: $showUpdatePercents) {
                            Text("Update standing split to these percentages")
                                .font(.subheadline)
                        }
                        .tint(Theme.primaryNavy)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 100)
            }
            
            VStack {
                PrimaryButton(
                    title: "Save and lock",
                    action: { showConfirmation = true },
                    isDisabled: !isValid
                )
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Assign credit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            for goal in activeGoals {
                customPercents[goal.id] = goal.creditSharePercent
            }
        }
        .alert("Save this split?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                saveCredit()
            }
        } message: {
            Text("This entry will be locked after saving.")
        }
    }
    
    private func splitAmount(for goal: Goal) -> Decimal {
        (creditAmount * Decimal(goal.creditSharePercent)) / 100
    }
    
    private func customSplitAmount(for goal: Goal) -> Decimal {
        let percent = customPercents[goal.id] ?? 0
        return (creditAmount * Decimal(percent)) / 100
    }
    
    private func saveCredit() {
        var splits: [GoalSplit] = []
        
        for goal in activeGoals {
            let percent: Int
            let amount: Decimal
            
            if useStandingSplit {
                percent = goal.creditSharePercent
                amount = splitAmount(for: goal)
            } else {
                percent = customPercents[goal.id] ?? 0
                amount = customSplitAmount(for: goal)
                
                if showUpdatePercents {
                    goal.creditSharePercent = percent
                }
            }
            
            goal.savedAmount += amount
            goal.updatedAt = Date()
            
            splits.append(GoalSplit(
                goalId: goal.id,
                goalName: goal.name,
                amount: amount,
                percent: percent
            ))
        }
        
        let entry = HistoryEntry(
            type: useStandingSplit ? .newCredit : .customSplit,
            totalAmount: creditAmount,
            splits: splits,
            isLocked: true
        )
        
        modelContext.insert(entry)
        try? modelContext.save()
        
        dismiss()
    }
}

struct StandingSplitRow: View {
    let goal: Goal
    let amount: Decimal
    
    var body: some View {
        HStack {
            if let emoji = goal.emoji {
                Text(emoji)
                    .font(.title3)
            }
            
            Text(goal.name)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(amount.formattedINR)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Text("\(goal.creditSharePercent)%")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CustomSplitRow: View {
    let goal: Goal
    @Binding var percent: Int
    let amount: Decimal
    
    var body: some View {
        HStack {
            if let emoji = goal.emoji {
                Text(emoji)
                    .font(.title3)
            }
            
            Text(goal.name)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { if percent > 0 { percent -= 5 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(percent > 0 ? Theme.primaryNavy : .gray)
                }
                .disabled(percent <= 0)
                
                Text("\(percent)%")
                    .font(.headline)
                    .frame(minWidth: 40)
                
                Button(action: { if percent < 100 { percent += 5 } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(percent < 100 ? Theme.primaryNavy : .gray)
                }
                .disabled(percent >= 100)
            }
            
            Text(amount.formattedINR)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AssignCreditView(creditAmount: 25000)
    }
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
