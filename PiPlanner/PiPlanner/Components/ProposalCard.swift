import SwiftUI

/// Shared proposal shell — “Grok's proposal” hierarchy, Edit / Confirm, footer caption
/// (PRD R9 / R17 · Tech Spec §3.5). Visual only; callbacks unchanged from PIP-63 Ask usage.
struct ProposalCard: View {
    let title: String
    let summary: String
    let checkedByLabel: String
    var onEdit: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text(title)
                    .font(PiTypography.title())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ask.proposal.title")

                Text(summary)
                    .font(PiTypography.body())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("ask.proposal.summary")

                Text(checkedByLabel)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(checkedByLabel)
                    .accessibilityIdentifier("ask.proposal.checkedBy")

                HStack(spacing: DesignTokens.Space.s12) {
                    SecondaryCTA(
                        title: "Edit",
                        style: .outline,
                        accessibilityIdentifier: "ask.proposal.edit",
                        action: onEdit
                    )

                    PrimaryCTA(
                        title: "Confirm",
                        accessibilityIdentifier: "ask.proposal.confirm",
                        action: onConfirm
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask.proposal.card")
    }
}

#Preview("ProposalCard") {
    ZStack {
        PiColors.backgroundApp.ignoresSafeArea()
        ProposalCard(
            title: "Grok's proposal",
            summary: "Car → Emergency Fund · ₹5,000",
            checkedByLabel: "Checked by PiPlanner. Estimate.",
            onEdit: {},
            onConfirm: {}
        )
        .padding(DesignTokens.Space.s20)
    }
    .piPlannerTheme()
}
