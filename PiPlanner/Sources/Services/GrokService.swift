import Foundation

@MainActor
class GrokService: ObservableObject {
    @Published var isAvailable: Bool = true
    
    static let shared = GrokService()
    
    func parseGoals(from input: String, currentBalance: Decimal) async -> GrokResponse {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        guard isAvailable else {
            return .unavailable
        }
        
        let normalizedInput = input.lowercased()
        var goals: [GrokProposal.GoalDraft] = []
        
        if normalizedInput.contains("car") {
            goals.append(GrokProposal.GoalDraft(
                name: "Car",
                targetAmount: 500000,
                endDate: Calendar.current.date(byAdding: .month, value: 24, to: Date())!,
                emoji: "🚗"
            ))
        }
        
        if normalizedInput.contains("emergency") || normalizedInput.contains("fund") {
            goals.append(GrokProposal.GoalDraft(
                name: "Emergency",
                targetAmount: 200000,
                endDate: Calendar.current.date(byAdding: .month, value: 12, to: Date())!,
                emoji: "🏥"
            ))
        }
        
        if normalizedInput.contains("vacation") || normalizedInput.contains("trip") || normalizedInput.contains("travel") {
            goals.append(GrokProposal.GoalDraft(
                name: "Vacation",
                targetAmount: 150000,
                endDate: Calendar.current.date(byAdding: .month, value: 18, to: Date())!,
                emoji: "✈️"
            ))
        }
        
        if normalizedInput.contains("wedding") || normalizedInput.contains("marriage") {
            goals.append(GrokProposal.GoalDraft(
                name: "Wedding",
                targetAmount: 1000000,
                endDate: Calendar.current.date(byAdding: .month, value: 36, to: Date())!,
                emoji: "💒"
            ))
        }
        
        if normalizedInput.contains("house") || normalizedInput.contains("home") || normalizedInput.contains("flat") {
            goals.append(GrokProposal.GoalDraft(
                name: "Home Down Payment",
                targetAmount: 2000000,
                endDate: Calendar.current.date(byAdding: .month, value: 48, to: Date())!,
                emoji: "🏠"
            ))
        }
        
        if normalizedInput.contains("laptop") || normalizedInput.contains("computer") || normalizedInput.contains("phone") {
            goals.append(GrokProposal.GoalDraft(
                name: "Gadgets",
                targetAmount: 100000,
                endDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!,
                emoji: "💻"
            ))
        }
        
        if goals.isEmpty {
            goals = [
                GrokProposal.GoalDraft(
                    name: "Car",
                    targetAmount: 500000,
                    endDate: Calendar.current.date(byAdding: .month, value: 24, to: Date())!,
                    emoji: "🚗"
                ),
                GrokProposal.GoalDraft(
                    name: "Emergency",
                    targetAmount: 200000,
                    endDate: Calendar.current.date(byAdding: .month, value: 12, to: Date())!,
                    emoji: "🏥"
                )
            ]
        }
        
        let proposal = GrokProposal(
            goals: goals,
            message: "Based on your goals, here's what I suggest:"
        )
        
        return .success(proposal)
    }
    
    func generateTransferSuggestions(from: Goal, to: Goal, available: Decimal) -> [Decimal] {
        let suggestions: [Decimal] = [1000, 5000, 10000]
        return suggestions.filter { $0 <= available }
    }
    
    func answerQuestion(_ question: String) async -> AskResponse {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        guard isAvailable else {
            return .unavailable
        }
        
        let normalizedQuestion = question.lowercased()
        
        if normalizedQuestion.contains("transfer") || normalizedQuestion.contains("move") {
            return .actionSuggestion(
                message: "I can help you transfer money between goals. Would you like me to set up a transfer?",
                action: .transfer
            )
        }
        
        if normalizedQuestion.contains("goal") && (normalizedQuestion.contains("add") || normalizedQuestion.contains("new") || normalizedQuestion.contains("create")) {
            return .actionSuggestion(
                message: "Let's create a new savings goal for you.",
                action: .newGoal
            )
        }
        
        if normalizedQuestion.contains("balance") || normalizedQuestion.contains("sync") {
            return .plainAnswer("Your balance was last synced and is currently up to date. You can tap the Sync button to check for any new credits.")
        }
        
        if normalizedQuestion.contains("behind") || normalizedQuestion.contains("catch up") {
            return .plainAnswer("To catch up on your goals, consider increasing your monthly savings or adjusting your goal targets. You can also transfer funds between goals if one has excess.")
        }
        
        return .plainAnswer("I'm here to help with your savings goals! You can ask me to transfer money between goals, add new goals, or check your progress.")
    }
    
    enum GrokResponse {
        case success(GrokProposal)
        case needsMoreInfo(String)
        case unavailable
    }
    
    enum AskResponse {
        case plainAnswer(String)
        case actionSuggestion(message: String, action: SuggestedAction)
        case unavailable
        
        enum SuggestedAction {
            case transfer
            case newGoal
            case sync
        }
    }
}
