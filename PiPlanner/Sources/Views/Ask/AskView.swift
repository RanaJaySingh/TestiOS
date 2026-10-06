import SwiftUI
import SwiftData

struct AskView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Query private var goals: [Goal]
    
    @State private var userInput: String = ""
    @State private var messages: [AskMessage] = []
    @State private var isLoading: Bool = false
    @State private var showTransfer: Bool = false
    @State private var showNewGoal: Bool = false
    @StateObject private var grokService = GrokService.shared
    
    struct AskMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        var suggestedAction: GrokService.AskResponse.SuggestedAction?
    }
    
    private var suggestionChips: [String] {
        [
            "How am I doing?",
            "Transfer between goals",
            "Add a new goal",
            "Why am I behind?"
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if messages.isEmpty {
                            welcomeSection
                        }
                        
                        ForEach(messages) { message in
                            MessageBubble(message: message) {
                                handleAction(message.suggestedAction)
                            }
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Grok is thinking...")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding()
                        }
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 120)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            VStack(spacing: 12) {
                if messages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestionChips, id: \.self) { chip in
                                Button(action: {
                                    userInput = chip
                                    sendMessage()
                                }) {
                                    Text(chip)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Theme.cardBackground)
                                        .foregroundColor(Theme.primaryNavy)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Theme.primaryNavy.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("Ask Grok...", text: $userInput)
                        .padding(12)
                        .background(Theme.cardBackground)
                        .cornerRadius(Theme.cornerRadius)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(userInput.isEmpty ? Theme.primaryNavy.opacity(0.3) : Theme.primaryNavy)
                    }
                    .disabled(userInput.isEmpty || isLoading)
                }
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationTitle("Ask")
        .sheet(isPresented: $showTransfer) {
            NavigationStack {
                TransferView()
            }
        }
        .sheet(isPresented: $showNewGoal) {
            NavigationStack {
                GoalFormScreen(
                    isInitialSetup: false,
                    onSave: { draft in
                        createGoal(from: draft)
                    }
                )
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Theme.primaryNavy)
            
            Text("Ask Grok")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("I can help you manage your savings goals, transfer money between goals, or answer questions about your progress.")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            if !grokService.isAvailable {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("Grok is currently unavailable")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("Powered by Grok")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
    
    private func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(AskMessage(text: trimmed, isUser: true))
        userInput = ""
        isLoading = true
        
        Task {
            let response = await grokService.answerQuestion(trimmed)
            
            await MainActor.run {
                isLoading = false
                
                switch response {
                case .plainAnswer(let answer):
                    messages.append(AskMessage(text: answer, isUser: false))
                    
                case .actionSuggestion(let message, let action):
                    messages.append(AskMessage(text: message, isUser: false, suggestedAction: action))
                    
                case .unavailable:
                    messages.append(AskMessage(text: "I'm currently unavailable. Please try again later or use the app's features directly.", isUser: false))
                }
            }
        }
    }
    
    private func handleAction(_ action: GrokService.AskResponse.SuggestedAction?) {
        switch action {
        case .transfer:
            showTransfer = true
        case .newGoal:
            showNewGoal = true
        case .sync:
            appState.selectedTab = .goals
        case .none:
            break
        }
    }
    
    private func createGoal(from draft: GrokProposal.GoalDraft) {
        let activeGoals = goals.filter { $0.isActive }
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
        try? modelContext.save()
    }
}

struct MessageBubble: View {
    let message: AskView.AskMessage
    var onAction: (() -> Void)?
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            HStack {
                if message.isUser { Spacer() }
                
                Text(message.text)
                    .font(.body)
                    .padding(12)
                    .background(message.isUser ? Theme.primaryNavy : Theme.cardBackground)
                    .foregroundColor(message.isUser ? .white : Theme.textPrimary)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(message.isUser ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                
                if !message.isUser { Spacer() }
            }
            
            if let action = message.suggestedAction {
                Button(action: { onAction?() }) {
                    HStack {
                        Text(actionButtonTitle(for: action))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.primaryNavy)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
            }
        }
    }
    
    private func actionButtonTitle(for action: GrokService.AskResponse.SuggestedAction) -> String {
        switch action {
        case .transfer: return "Open Transfer"
        case .newGoal: return "Create Goal"
        case .sync: return "Sync Balance"
        }
    }
}

#Preview {
    NavigationStack {
        AskView()
    }
    .environmentObject(AppState())
    .modelContainer(for: [Account.self, Goal.self, HistoryEntry.self, UserSettings.self], inMemory: true)
}
