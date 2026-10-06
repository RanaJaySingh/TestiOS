import SwiftUI

struct OpeningSplitScreen: View {
    let goals: [GrokProposal.GoalDraft]
    @Binding var percents: [UUID: Int]
    let currentBalance: Decimal
    let onLock: () -> Void
    
    @State private var localPercents: [Int]
    @State private var showLockConfirmation: Bool = false
    
    init(goals: [GrokProposal.GoalDraft], percents: Binding<[UUID: Int]>, currentBalance: Decimal, onLock: @escaping () -> Void) {
        self.goals = goals
        self._percents = percents
        self.currentBalance = currentBalance
        self.onLock = onLock
        
        let count = goals.count
        let equalShare = count > 0 ? 100 / count : 0
        let remainder = count > 0 ? 100 % count : 0
        self._localPercents = State(initialValue: goals.enumerated().map { index, _ in
            equalShare + (index < remainder ? 1 : 0)
        })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Opening split")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("How should we split your current \(currentBalance.formattedINR) across your goals?")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 16)
                    
                    if goals.count == 1 {
                        SingleGoalSplit(goal: goals[0], amount: currentBalance)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(Array(goals.enumerated()), id: \.element.name) { index, goal in
                                GoalSplitRow(
                                    goal: goal,
                                    percent: Binding(
                                        get: { localPercents[safe: index] ?? 0 },
                                        set: { newValue in
                                            if index < localPercents.count {
                                                localPercents[index] = newValue
                                            }
                                        }
                                    ),
                                    amount: splitAmount(for: index),
                                    needsPerMonth: needsPerMonth(for: goal)
                                )
                            }
                            
                            Divider()
                            
                            TotalPercentValidation(totalPercent: totalPercent)
                        }
                        .padding(Theme.cardPadding)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    
                    if isValid {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("After this split")
                                .font(.headline)
                            
                            ForEach(Array(goals.enumerated()), id: \.element.name) { index, goal in
                                HStack {
                                    if let emoji = goal.emoji {
                                        Text(emoji)
                                    }
                                    Text(goal.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(splitAmount(for: index).formattedINR)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding(Theme.cardPadding)
                        .background(Theme.primaryNavy.opacity(0.05))
                        .cornerRadius(Theme.cornerRadius)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 100)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Theme.textSecondary)
                    Text("This split locks after saving")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                PrimaryButton(
                    title: "Lock this split",
                    action: { showLockConfirmation = true },
                    isDisabled: !isValid
                )
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Split your savings")
        .alert("Lock this split?", isPresented: $showLockConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Lock") {
                syncPercentsToBinding()
                onLock()
            }
        } message: {
            Text("Once locked, this entry cannot be changed. Future credits will use these percentages.")
        }
    }
    
    private var totalPercent: Int {
        localPercents.reduce(0, +)
    }
    
    private var isValid: Bool {
        totalPercent == 100
    }
    
    private func splitAmount(for index: Int) -> Decimal {
        let percent = localPercents[safe: index] ?? 0
        return (currentBalance * Decimal(percent)) / 100
    }
    
    private func needsPerMonth(for goal: GrokProposal.GoalDraft) -> Decimal {
        let months = Calendar.current.dateComponents([.month], from: Date(), to: goal.endDate).month ?? 1
        guard months > 0 else { return 0 }
        return goal.targetAmount / Decimal(months)
    }
    
    private func syncPercentsToBinding() {
        var newPercents: [UUID: Int] = [:]
        for (index, _) in goals.enumerated() {
            newPercents[UUID()] = localPercents[safe: index] ?? 0
        }
        percents = newPercents
    }
}

struct GoalSplitRow: View {
    let goal: GrokProposal.GoalDraft
    @Binding var percent: Int
    let amount: Decimal
    let needsPerMonth: Decimal
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let emoji = goal.emoji {
                    Text(emoji)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                    
                    Text("needs \(needsPerMonth.formattedINR)/month")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { if percent > 0 { percent -= 5 } }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(percent > 0 ? Theme.primaryNavy : .gray)
                    }
                    .disabled(percent <= 0)
                    
                    Text("\(percent)%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(minWidth: 50)
                    
                    Button(action: { if percent < 100 { percent += 5 } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(percent < 100 ? Theme.primaryNavy : .gray)
                    }
                    .disabled(percent >= 100)
                }
            }
            
            HStack {
                Text(amount.formattedINR)
                    .font(.subheadline)
                    .foregroundColor(Theme.primaryNavy)
                Spacer()
            }
        }
    }
}

struct SingleGoalSplit: View {
    let goal: GrokProposal.GoalDraft
    let amount: Decimal
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                if let emoji = goal.emoji {
                    Text(emoji)
                        .font(.title)
                }
                
                Text(goal.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("100%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primaryNavy)
            }
            
            Text("Your entire balance of \(amount.formattedINR) goes to this goal.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        OpeningSplitScreen(
            goals: [
                .init(name: "Car", targetAmount: 500000, endDate: Calendar.current.date(byAdding: .year, value: 2, to: Date())!, emoji: "🚗"),
                .init(name: "Emergency", targetAmount: 200000, endDate: Calendar.current.date(byAdding: .year, value: 1, to: Date())!, emoji: "🏥")
            ],
            percents: .constant([:]),
            currentBalance: 100000,
            onLock: {}
        )
    }
}
