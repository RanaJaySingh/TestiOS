import SwiftUI

/// Goal chat — design frames 5 / 5a / 5b / 5c, with form hand-off (6) and goals-defined Continue.
struct GoalChatView: View {
    @ObservedObject var viewModel: GoalChatViewModel
    var onContinueToOpeningSplit: () -> Void

    var body: some View {
        Group {
            if viewModel.phase == .form {
                GoalFormView(viewModel: viewModel)
            } else {
                chatBody
            }
        }
        .onChange(of: viewModel.shouldNavigateToOpeningSplit) { shouldNavigate in
            if shouldNavigate {
                onContinueToOpeningSplit()
            }
        }
    }

    private var chatBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        messageBubble(message)
                    }

                    if viewModel.phase == .proposal {
                        proposalCard
                    }

                    if viewModel.phase == .unavailable {
                        unavailableCard
                    }

                    if viewModel.phase == .goalsDefined || !viewModel.definedGoals.isEmpty {
                        goalsDefinedSection
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.phase == .chat
                || viewModel.phase == .followUp
                || viewModel.phase == .proposal {
                composer
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.phase != .unavailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use a form") {
                        viewModel.useFormPath()
                    }
                    .accessibilityLabel("Use a form")
                }
            }
        }
    }

    private func messageBubble(_ message: GoalChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.body)
                .padding(12)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(
                    message.role == .user
                        ? "You: \(message.text)"
                        : "Assistant: \(message.text)"
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var proposalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested goals")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.proposals) { proposal in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(proposal.name)
                            .font(.body)
                            .fontWeight(.semibold)
                        Text(
                            viewModel.formatINR(paisa: proposal.suggestedTarget ?? 0)
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                    Spacer()
                    Text("\(GoalValidationService.displayPercent(fromFraction: proposal.sharePercentage))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }

            Text(viewModel.checkedByLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(viewModel.checkedByLabel)

            HStack(spacing: 12) {
                Button("Edit") {
                    viewModel.editProposals()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Edit proposal")

                Button("Confirm") {
                    viewModel.confirmProposals()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Confirm proposal")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grok unavailable")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("You can keep going with a hand form. Ledger rules still apply.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Use a form") {
                viewModel.useFormPath()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Use a form")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var goalsDefinedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals defined")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.definedGoals) { goal in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.name)
                            .font(.body)
                            .fontWeight(.semibold)
                        Text(viewModel.formatINR(paisa: goal.targetAmount))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    TextField(
                        "%",
                        value: Binding(
                            get: {
                                GoalValidationService.displayPercent(
                                    fromFraction: goal.shareOfNewCredits
                                )
                            },
                            set: { viewModel.updateShare(for: goal.id, displayPercent: $0) }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .accessibilityLabel("\(goal.name) share percent")
                    Text("%")
                        .foregroundStyle(.secondary)
                    Button("Edit") {
                        viewModel.editDefinedGoal(goal)
                    }
                    .font(.subheadline)
                }
            }

            if let reason = viewModel.continueDisabledReason {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Shares total 100%. Continue to Opening split.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.continueToOpeningSplit()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canContinue)
            .accessibilityLabel("Continue")
            .accessibilityHint(
                viewModel.canContinue
                    ? "Continues to Opening split"
                    : "Disabled until goal shares total 100 percent"
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var composer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 10) {
                TextField("Describe your goals…", text: $viewModel.draftInput, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Goal description")
                Button {
                    viewModel.sendDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

#Preview("Chat") {
    NavigationStack {
        GoalChatView(viewModel: GoalChatViewModel()) {}
    }
}

#Preview("Unavailable") {
    NavigationStack {
        GoalChatView(viewModel: GoalChatViewModel(grok: StubGrokService(isUnavailable: true))) {}
    }
}
