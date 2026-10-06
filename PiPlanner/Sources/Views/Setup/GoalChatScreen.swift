import SwiftUI

struct GoalChatScreen: View {
    let currentBalance: Decimal
    let onGoalsCreated: ([GrokProposal.GoalDraft]) -> Void
    let onUseForm: () -> Void
    
    @State private var userInput: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @State private var proposal: GrokProposal?
    @State private var followUpCount: Int = 0
    @StateObject private var grokService = GrokService.shared
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What are you planning for?")
                                .font(.system(size: 24, weight: .bold))
                            
                            Text("Tell me about your savings goals. For example: \"I want to buy a car in 2 years for ₹5 lakh and build an emergency fund.\"")
                                .font(.body)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 16)
                        
                        ForEach(messages) { message in
                            ChatBubble(message: message)
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
                        
                        if let proposal = proposal {
                            GrokProposalCard(
                                proposal: proposal,
                                onEdit: onUseForm,
                                onConfirm: {
                                    onGoalsCreated(proposal.goals)
                                }
                            )
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
                if proposal == nil {
                    SuggestionChips(
                        suggestions: ["Car + Emergency", "Wedding savings", "Travel fund", "Home down payment"],
                        onSelect: { suggestion in
                            userInput = suggestion
                            sendMessage()
                        }
                    )
                }
                
                HStack(spacing: 12) {
                    TextField("Tell me your goals...", text: $userInput)
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
                
                TextButton(title: "Use a form", action: onUseForm)
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text("Plan your goals")
                        .font(.headline)
                    Spacer()
                    StepIndicator(currentStep: 3, totalSteps: 3)
                }
            }
        }
        .onAppear {
            if !grokService.isAvailable {
                onUseForm()
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(ChatMessage(text: trimmed, isUser: true))
        userInput = ""
        isLoading = true
        
        Task {
            let response = await grokService.parseGoals(from: trimmed, currentBalance: currentBalance)
            
            await MainActor.run {
                isLoading = false
                
                switch response {
                case .success(let prop):
                    if let message = prop.message {
                        messages.append(ChatMessage(text: message, isUser: false))
                    }
                    proposal = prop
                    
                case .needsMoreInfo(let question):
                    messages.append(ChatMessage(text: question, isUser: false))
                    followUpCount += 1
                    if followUpCount >= 2 {
                        onUseForm()
                    }
                    
                case .unavailable:
                    messages.append(ChatMessage(text: "I'm currently unavailable. Let's use the form instead.", isUser: false))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onUseForm()
                    }
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: GoalChatScreen.ChatMessage
    
    var body: some View {
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
    }
}

struct SuggestionChips: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { onSelect(suggestion) }) {
                        Text(suggestion)
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
}

#Preview {
    NavigationStack {
        GoalChatScreen(
            currentBalance: 100000,
            onGoalsCreated: { _ in },
            onUseForm: {}
        )
    }
}
