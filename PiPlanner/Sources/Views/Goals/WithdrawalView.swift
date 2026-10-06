import SwiftUI
import SwiftData

struct WithdrawalView: View {
    let withdrawalAmount: Decimal
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [Goal]
    
    @State private var goalAllocations: [UUID: Decimal] = [:]
    @State private var showConfirmation: Bool = false
    
    private var activeGoals: [Goal] {
        goals.filter { $0.isActive }
    }
    
    private var totalAllocated: Decimal {
        goalAllocations.values.reduce(0, +)
    }
    
    private var isValid: Bool {
        totalAllocated == withdrawalAmount && goalAllocations.allSatisfy { goalId, amount in
            guard let goal = activeGoals.first(where: { $0.id == goalId }) else { return false }
            return amount <= goal.savedAmount
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your savings balance went down by")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text(withdrawalAmount.formattedINR)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 16)
                    
                    Text("Choose which goals it comes from:")
                        .font(.headline)
                    
                    VStack(spacing: 16) {
                        ForEach(activeGoals) { goal in
                            WithdrawalGoalRow(
                                goal: goal,
                                allocation: Binding(
                                    get: { goalAllocations[goal.id] ?? 0 },
                                    set: { goalAllocations[goal.id] = $0 }
                                ),
                                maxAllocation: goal.savedAmount
                            )
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("\(totalAllocated.formattedINR) of \(withdrawalAmount.formattedINR)")
                                .font(.headline)
                                .foregroundColor(totalAllocated == withdrawalAmount ? .green : Theme.textPrimary)
                        }
                        
                        if totalAllocated != withdrawalAmount {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("Total must equal \(withdrawalAmount.formattedINR)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .background(Theme.cardBackground)
                    .cornerRadius(Theme.cornerRadius)
                    
                    Button("Split proportionally") {
                        splitProportionally()
                    }
                    .font(.subheadline)
                    .foregroundColor(Theme.primaryNavy)
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
        .navigationTitle("Record withdrawal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            splitProportionally()
        }
        .alert("Record withdrawal?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                recordWithdrawal()
            }
        } message: {
            Text("This will deduct the amounts from your goals and lock the entry.")
        }
    }
    
    private func splitProportionally() {
        let totalSaved = activeGoals.reduce(Decimal(0)) { $0 + $1.savedAmount }
        guard totalSaved > 0 else { return }
        
        var remaining = withdrawalAmount
        
        for (index, goal) in activeGoals.enumerated() {
            if index == activeGoals.count - 1 {
                goalAllocations[goal.id] = min(remaining, goal.savedAmount)
            } else {
                let proportion = goal.savedAmount / totalSaved
                let amount = min((withdrawalAmount * proportion).rounded(), goal.savedAmount)
                goalAllocations[goal.id] = amount
                remaining -= amount
            }
        }
    }
    
    private func recordWithdrawal() {
        var splits: [GoalSplit] = []
        
        for goal in activeGoals {
            let amount = goalAllocations[goal.id] ?? 0
            if amount > 0 {
                goal.savedAmount -= amount
                goal.updatedAt = Date()
                
                splits.append(GoalSplit(
                    goalId: goal.id,
                    goalName: goal.name,
                    amount: amount,
                    percent: Int((amount / withdrawalAmount * 100).rounded())
                ))
            }
        }
        
        let entry = HistoryEntry(
            type: .withdrawal,
            totalAmount: withdrawalAmount,
            splits: splits,
            isLocked: true
        )
        
        modelContext.insert(entry)
        try? modelContext.save()
        
        dismiss()
    }
}

struct WithdrawalGoalRow: View {
    let goal: Goal
    @Binding var allocation: Decimal
    let maxAllocation: Decimal
    
    @State private var allocationText: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if let emoji = goal.emoji {
                    Text(emoji)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Available: \(maxAllocation.formattedINR)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack {
                    Text("₹")
                        .foregroundColor(Theme.textSecondary)
                    
                    TextField("0", text: $allocationText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: allocationText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            allocationText = filtered
                            allocation = min(Decimal(string: filtered) ?? 0, maxAllocation)
                        }
                }
                .padding(8)
                .background(Theme.background)
                .cornerRadius(8)
            }
            
            if allocation > maxAllocation {
                Text("Exceeds available amount")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            allocationText = "\(NSDecimalNumber(decimal: allocation).intValue)"
        }
    }
}

extension Decimal {
    func rounded() -> Decimal {
        var result = Decimal()
        var mutableSelf = self
        NSDecimalRound(&result, &mutableSelf, 0, .plain)
        return result
    }
}

#Preview {
    NavigationStack {
        WithdrawalView(withdrawalAmount: 8000)
    }
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
