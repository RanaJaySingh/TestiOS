import SwiftUI

/// Ask tab — stub Grok answers + Transfer proposal prefill (PIP-55 frame 16c).
/// Full Ask UI arrives in PIP-63; this keeps Transfer prefill reachable.
struct AskTabView: View {
    var persistence: (any PersistenceServicing)? = nil
    var goals: [Goal] = []
    var standingSplits: [StandingSplit] = []
    var grok: any GrokServicing = StubGrokService()
    var formatting: any FormattingServicing = FormattingService()

    @State private var query = "Transfer ₹5,000 from Car to Emergency Fund"
    @State private var answerText: String?
    @State private var transferPrefill: TransferService.Prefill?
    @State private var showTransfer = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ask")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Ask PiPlanner about your goals. Transfer proposals open Transfer pre-filled.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Ask a question…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("ask.query")

                Button("Ask") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ask.submit")

                if let answerText {
                    Text(answerText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("ask.answer")
                }

                if let transferPrefill {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Suggested transfer")
                            .font(.headline)
                        Text(proposalCaption(transferPrefill))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Open Transfer") {
                            showTransfer = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(persistence == nil || goals.count < 2)
                        .accessibilityIdentifier("ask.transfer.open")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("ask.transfer.proposal")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ask.tab")
        .sheet(isPresented: $showTransfer) {
            NavigationStack {
                if let persistence {
                    TransferFlow(
                        goals: goals,
                        standingSplits: standingSplits,
                        persistence: persistence,
                        formatting: formatting,
                        prefill: transferPrefill,
                        onCompleted: { showTransfer = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showTransfer = false }
                        }
                    }
                }
            }
        }
    }

    private func submit() {
        answerText = nil
        transferPrefill = nil
        errorMessage = nil
        switch grok.askQuestion(query: query) {
        case .failure(let error):
            errorMessage = String(describing: error)
        case .success(.plainAnswer(let text)):
            answerText = text
        case .success(.actionProposal(let action)):
            if let prefill = StubGrokService.transferPrefill(from: action) {
                transferPrefill = prefill
                answerText = "I can move that for you. Open Transfer to review and confirm."
            } else {
                answerText = "Proposal ready (not a Transfer)."
            }
        }
    }

    private func proposalCaption(_ prefill: TransferService.Prefill) -> String {
        let fromName = goals.first { $0.id == prefill.fromGoalId }?.name ?? "From"
        let toName = goals.first { $0.id == prefill.toGoalId }?.name ?? "To"
        let amount = prefill.amountPaisa ?? 0
        return TransferService.historyTitle(
            fromName: fromName,
            toName: toName,
            amountPaisa: amount,
            formatting: formatting
        )
    }
}

#Preview {
    NavigationStack {
        AskTabView()
    }
}
