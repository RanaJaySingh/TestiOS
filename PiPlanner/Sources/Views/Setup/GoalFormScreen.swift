import SwiftUI

struct GoalFormScreen: View {
    var isInitialSetup: Bool = false
    var existingGoal: Goal? = nil
    let onSave: (GrokProposal.GoalDraft) -> Void
    var onAddAnother: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var inflationRate: Double = 0.07
    @State private var savedSoFar: String = "0"
    @State private var showInflationPopup: Bool = false
    @State private var selectedEmoji: String = "🎯"
    
    private let emojiOptions = ["🎯", "🚗", "🏠", "✈️", "💒", "🏥", "💻", "📱", "🎓", "👶", "💼", "🏖️"]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal name")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            Menu {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button(emoji) {
                                        selectedEmoji = emoji
                                    }
                                }
                            } label: {
                                Text(selectedEmoji)
                                    .font(.title)
                                    .padding(8)
                                    .background(Theme.background)
                                    .cornerRadius(8)
                            }
                            
                            TextField("e.g. Car, Emergency fund", text: $name)
                                .font(.body)
                                .padding(12)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target amount")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        HStack {
                            Text("₹")
                                .font(.title2)
                                .foregroundColor(Theme.textSecondary)
                            
                            TextField("0", text: $targetAmount)
                                .font(.title2)
                                .keyboardType(.numberPad)
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                                .padding(8)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("End")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                                .padding(8)
                                .background(Theme.cardBackground)
                                .cornerRadius(Theme.cornerRadius)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inflation")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            Button(action: { showInflationPopup = true }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.primaryNavy)
                            }
                        }
                        
                        HStack {
                            Text("\(Int(inflationRate * 100))%")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Stepper("", value: $inflationRate, in: 0...0.15, step: 0.01)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    }
                    
                    if existingGoal != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saved so far")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            HStack {
                                Text("₹")
                                    .font(.title3)
                                    .foregroundColor(Theme.textSecondary)
                                
                                TextField("0", text: $savedSoFar)
                                    .font(.title3)
                                    .keyboardType(.numberPad)
                            }
                            .padding(12)
                            .background(Theme.cardBackground)
                            .cornerRadius(Theme.cornerRadius)
                        }
                    }
                    
                    if let target = Decimal(string: targetAmount.filter { $0.isNumber }), target > 0 {
                        SummaryCard(
                            targetAmount: target,
                            inflationRate: inflationRate,
                            startDate: startDate,
                            endDate: endDate
                        )
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            
            VStack(spacing: 12) {
                PrimaryButton(
                    title: existingGoal != nil ? "Save changes" : "Save goal",
                    action: saveGoal,
                    isDisabled: !isValid
                )
                
                if isInitialSetup, onAddAnother != nil {
                    SecondaryButton(title: "Add another goal", action: {
                        saveGoal()
                        onAddAnother?()
                    })
                }
                
                if existingGoal != nil, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Text("Delete goal")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(existingGoal != nil ? "Edit goal" : "New goal")
        .sheet(isPresented: $showInflationPopup) {
            InflationInfoSheet(inflationRate: $inflationRate)
                .presentationDetents([.medium])
        }
        .onAppear {
            if let goal = existingGoal {
                name = goal.name
                targetAmount = "\(NSDecimalNumber(decimal: goal.targetAmount).intValue)"
                startDate = goal.startDate
                endDate = goal.endDate
                inflationRate = goal.inflationRate
                savedSoFar = "\(NSDecimalNumber(decimal: goal.savedAmount).intValue)"
                selectedEmoji = goal.emoji ?? "🎯"
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Decimal(string: targetAmount.filter { $0.isNumber }) ?? 0) > 0 &&
        endDate > startDate
    }
    
    private func saveGoal() {
        guard isValid else { return }
        
        let target = Decimal(string: targetAmount.filter { $0.isNumber }) ?? 0
        
        let draft = GrokProposal.GoalDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: target,
            endDate: endDate,
            inflationRate: inflationRate,
            emoji: selectedEmoji
        )
        
        onSave(draft)
        dismiss()
    }
}

struct SummaryCard: View {
    let targetAmount: Decimal
    let inflationRate: Double
    let startDate: Date
    let endDate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target with inflation")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(targetWithInflation.formattedINR)
                    .font(.headline)
            }
            
            HStack {
                Text("Needs per month")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(needsPerMonth.formattedINR)
                    .font(.headline)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.primaryNavy.opacity(0.05))
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var targetWithInflation: Decimal {
        let years = Double(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) / 365.0
        let inflationMultiplier = pow(1 + inflationRate, years)
        return targetAmount * Decimal(inflationMultiplier)
    }
    
    private var needsPerMonth: Decimal {
        let months = Calendar.current.dateComponents([.month], from: Date(), to: endDate).month ?? 1
        guard months > 0 else { return 0 }
        return targetWithInflation / Decimal(months)
    }
}

struct InflationInfoSheet: View {
    @Binding var inflationRate: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Inflation adjustment")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Prices tend to rise over time. We adjust your target to account for this.")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Text("\(Int(inflationRate * 100))%")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.primaryNavy)
                
                Text("per year")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Slider(value: $inflationRate, in: 0...0.15, step: 0.01)
                    .tint(Theme.primaryNavy)
                    .padding(.horizontal)
            }
            
            Text("India's average inflation is around 5-7%. Adjust based on what you're saving for.")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            PrimaryButton(title: "Done", action: { dismiss() })
        }
        .padding(Theme.screenPadding)
    }
}

#Preview {
    NavigationStack {
        GoalFormScreen(
            isInitialSetup: true,
            onSave: { _ in }
        )
    }
}
