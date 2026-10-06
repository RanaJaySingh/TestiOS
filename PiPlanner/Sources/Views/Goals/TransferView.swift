import SwiftUI
import SwiftData

struct TransferView: View {
    var preselectedFrom: Goal? = nil
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [Goal]
    
    @State private var fromGoal: Goal?
    @State private var toGoal: Goal?
    @State private var amount: Decimal = 0
    @State private var amountText: String = ""
    @State private var showConfirmation: Bool = false
    
    private var activeGoals: [Goal] {
        goals.filter { $0.isActive }
    }
    
    private var availableAmount: Decimal {
        fromGoal?.savedAmount ?? 0
    }
    
    private var isValid: Bool {
        guard let from = fromGoal, let to = toGoal else { return false }
        return from.id != to.id && amount > 0 && amount <= availableAmount
    }
    
    private var suggestedAmounts: [Decimal] {
        [1000, 5000, 10000].filter { $0 <= availableAmount }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("From")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        GoalPicker(
                            goals: activeGoals,
                            selected: $fromGoal,
                            excluding: toGoal
                        )
                        
                        if let from = fromGoal {
                            HStack {
                                Text("Available:")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                Text(from.savedAmount.formattedINR)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    Image(systemName: "arrow.down")
                        .font(.title2)
                        .foregroundColor(Theme.primaryNavy)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("To")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        GoalPicker(
                            goals: activeGoals,
                            selected: $toGoal,
                            excluding: fromGoal
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            Text("₹")
                                .font(.title)
                                .foregroundColor(Theme.textSecondary)
                            
                            TextField("0", text: $amountText)
                                .font(.system(size: 36, weight: .bold))
                                .keyboardType(.numberPad)
                                .onChange(of: amountText) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    amountText = filtered
                                    amount = Decimal(string: filtered) ?? 0
                                }
                        }
                        
                        if !suggestedAmounts.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(suggestedAmounts, id: \.self) { suggestion in
                                    Button(action: {
                                        amount = suggestion
                                        amountText = "\(NSDecimalNumber(decimal: suggestion).intValue)"
                                    }) {
                                        Text(suggestion.formattedINR)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Theme.primaryNavy.opacity(0.1))
                                            .foregroundColor(Theme.primaryNavy)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        
                        if amount > availableAmount && fromGoal != nil {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.orange)
                                Text("Insufficient funds in \(fromGoal?.name ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    if isValid, let from = fromGoal, let to = toGoal {
                        previewCard(from: from, to: to)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            
            VStack {
                PrimaryButton(
                    title: "Move \(amount.formattedINR)",
                    action: { showConfirmation = true },
                    isDisabled: !isValid
                )
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear {
            if let preselected = preselectedFrom {
                fromGoal = preselected
            }
        }
        .alert("Confirm transfer", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Transfer") {
                executeTransfer()
            }
        } message: {
            if let from = fromGoal, let to = toGoal {
                Text("Move \(amount.formattedINR) from \(from.name) to \(to.name)?")
            }
        }
    }
    
    private func previewCard(from: Goal, to: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("After transfer")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(from.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(from.savedAmount.formattedINR) → \((from.savedAmount - amount).formattedINR)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(to.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(to.savedAmount.formattedINR) → \((to.savedAmount + amount).formattedINR)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.primaryNavy.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func executeTransfer() {
        guard let from = fromGoal, let to = toGoal, isValid else { return }
        
        from.savedAmount -= amount
        to.savedAmount += amount
        from.updatedAt = Date()
        to.updatedAt = Date()
        
        let entry = HistoryEntry(
            type: .transfer,
            totalAmount: amount,
            splits: [
                GoalSplit(goalId: from.id, goalName: from.name, amount: -amount, percent: 0),
                GoalSplit(goalId: to.id, goalName: to.name, amount: amount, percent: 0)
            ],
            note: "From \(from.name) to \(to.name)",
            isLocked: true
        )
        
        modelContext.insert(entry)
        try? modelContext.save()
        
        dismiss()
    }
}

struct GoalPicker: View {
    let goals: [Goal]
    @Binding var selected: Goal?
    var excluding: Goal? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(goals.filter { $0.id != excluding?.id }) { goal in
                Button(action: { selected = goal }) {
                    HStack {
                        if let emoji = goal.emoji {
                            Text(emoji)
                                .font(.title3)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(goal.savedAmount.formattedINR)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if selected?.id == goal.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.primaryNavy)
                        }
                    }
                    .padding(12)
                    .background(selected?.id == goal.id ? Theme.primaryNavy.opacity(0.1) : Theme.cardBackground)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected?.id == goal.id ? Theme.primaryNavy : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TransferView()
    }
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
