import SwiftUI

/// Goal chat — design frames 5 / 5a / 5b / 5c, with form hand-off (6) and goals-defined Continue.
/// Visual parity (PIP-79): tokens + ProposalCard / PiCard / PrimaryCTA / SecondaryCTA only.
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
                VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
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
                .padding(DesignTokens.Space.s20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.phase == .chat
                || viewModel.phase == .followUp
                || viewModel.phase == .proposal {
                composer
            }
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.phase != .unavailable {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use a form") {
                        viewModel.useFormPath()
                    }
                    .font(PiTypography.body())
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityLabel("Use a form")
                }
            }
        }
        .piPlannerTheme()
    }

    private func messageBubble(_ message: GoalChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(PiTypography.body())
                .foregroundStyle(message.role == .user ? PiColors.chipLightBlueLabel : .primary)
                .padding(DesignTokens.Space.s12)
                .background(bubbleBackground(for: message.role))
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                )
                .accessibilityLabel(
                    message.role == .user
                        ? "You: \(message.text)"
                        : "Assistant: \(message.text)"
                )
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func bubbleBackground(for role: GoalChatMessage.Role) -> Color {
        switch role {
        case .user:
            return PiColors.chipLightBlue
        case .assistant:
            return PiColors.surfaceCard
        }
    }

    /// Shared ProposalCard shell — title / summary / checked-by / Edit·Confirm (PRD R9).
    private var proposalCard: some View {
        ProposalCard(
            title: "Grok's proposal",
            summary: proposalSummary,
            checkedByLabel: viewModel.checkedByLabel,
            onEdit: { viewModel.editProposals() },
            onConfirm: { viewModel.confirmProposals() }
        )
        .accessibilityElement(children: .contain)
    }

    private var proposalSummary: String {
        viewModel.formattedProposals.map { proposal, target in
            let percent = GoalValidationService.displayPercent(fromFraction: proposal.sharePercentage)
            return "\(proposal.name) · \(target) · \(percent)%"
        }
        .joined(separator: "\n")
    }

    private var unavailableCard: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("Grok unavailable")
                    .font(PiTypography.title())
                    .accessibilityAddTraits(.isHeader)
                Text("You can keep going with a hand form. Ledger rules still apply.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryCTA(title: "Use a form", action: { viewModel.useFormPath() })
                    .accessibilityLabel("Use a form")
            }
        }
    }

    private var goalsDefinedSection: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text("Goals defined")
                    .font(PiTypography.title())
                    .accessibilityAddTraits(.isHeader)

                ForEach(viewModel.definedGoals) { goal in
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
                            Text(goal.name)
                                .font(PiTypography.body())
                                .fontWeight(.semibold)
                            Text(viewModel.formatINR(paisa: goal.targetAmount))
                                .font(PiTypography.caption())
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
                        .font(PiTypography.title())
                        .monospacedDigit()
                        .frame(width: 56)
                        .accessibilityLabel("\(goal.name) share percent")
                        Text("%")
                            .font(PiTypography.body())
                            .foregroundStyle(.secondary)
                        Button("Edit") {
                            viewModel.editDefinedGoal(goal)
                        }
                        .font(PiTypography.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.navyPrimary)
                    }
                }

                if let reason = viewModel.continueDisabledReason {
                    Text(reason)
                        .font(PiTypography.caption())
                        .foregroundStyle(PiColors.behind)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Shares total 100%. Continue to Opening split.")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                }

                PrimaryCTA(
                    title: "Continue",
                    isEnabled: viewModel.canContinue,
                    action: { viewModel.continueToOpeningSplit() }
                )
                .accessibilityLabel("Continue")
                .accessibilityHint(
                    viewModel.canContinue
                        ? "Continues to Opening split"
                        : "Disabled until goal shares total 100 percent"
                )
            }
        }
    }

    private var composer: some View {
        VStack(spacing: DesignTokens.Space.s8) {
            Divider()
            HStack(spacing: DesignTokens.Space.s12) {
                TextField("Describe your goals…", text: $viewModel.draftInput, axis: .vertical)
                    .lineLimit(1...4)
                    .font(PiTypography.body())
                    .padding(.horizontal, DesignTokens.Space.s12)
                    .padding(.vertical, DesignTokens.Space.s8)
                    .background(PiColors.surfaceCard)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                            .strokeBorder(PiColors.navyPrimary.opacity(0.18), lineWidth: 1)
                    )
                    .accessibilityLabel("Goal description")
                Button {
                    viewModel.sendDraft()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            viewModel.canSend
                                ? PiColors.navyPrimary
                                : PiColors.navyPrimary.opacity(0.35)
                        )
                }
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, DesignTokens.Space.s16)
            .padding(.vertical, DesignTokens.Space.s12)
        }
        .background(PiColors.surfaceCard)
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
