import SwiftUI

/// Preview catalog for PIP-69 acceptance — navy CTA, outline/text secondary,
/// light-blue chip states, sheet chrome, ProposalCard hierarchy.
struct ComponentsCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s28) {
                sectionTitle("PiCard")
                PiCard {
                    Text("White surface · radius \(Int(DesignTokens.Radius.card)) · soft shadow")
                        .font(PiTypography.body())
                }

                sectionTitle("Primary CTA")
                PrimaryCTA(title: "Enabled · Set up savings", isEnabled: true, action: {})
                PrimaryCTA(title: "Disabled · Continue", isEnabled: false, action: {})

                sectionTitle("Secondary CTA")
                SecondaryCTA(title: "Outline · Cancel", style: .outline, action: {})
                SecondaryCTA(title: "Text · Use a form", style: .text, action: {})

                sectionTitle("LightBlueChip")
                HStack(spacing: DesignTokens.Space.s12) {
                    LightBlueChip(title: "Unselected", isSelected: false, action: {})
                    LightBlueChip(title: "Selected", isSelected: true, action: {})
                }

                sectionTitle("ProposalCard")
                ProposalCard(
                    title: "Grok's proposal",
                    summary: "Car → Emergency Fund · ₹5,000",
                    checkedByLabel: "Checked by PiPlanner. Estimate.",
                    onEdit: {},
                    onConfirm: {}
                )

                sectionTitle("PiSheet")
                PiSheet(
                    title: "Sync balance",
                    helper: "Previous / Fetched / New amount"
                ) {
                    Text("Paytm-like top radius + title spacing.")
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Space.s20)
                        .padding(.bottom, DesignTokens.Space.s20)
                }
            }
            .padding(DesignTokens.Space.s20)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .piPlannerTheme()
        .accessibilityIdentifier("components.catalog")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(PiTypography.caption())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

#Preview("PIP-69 Components catalog") {
    ComponentsCatalog()
}
