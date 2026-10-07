import SwiftUI

/// Individual goal card — saved/of target, status, monthly need, % of credits (frames 9 / 11).
/// Visual restyle only (PIP-81 / Tech Spec §3.5 GoalCard).
struct GoalCard: View {
    let name: String
    /// e.g. "₹60,000 of ₹13,10,796"
    let formattedSavedOfTarget: String
    let statusLabel: String
    /// e.g. "Needs ₹26,058 a month"
    let monthlyNeedLabel: String
    /// e.g. "60% of credits"
    let creditsPercentLabel: String

    var body: some View {
        PiCard {
            HStack(alignment: .top, spacing: DesignTokens.Space.s12) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text(name)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(formattedSavedOfTarget)
                        .font(PiTypography.title())
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(monthlyNeedLabel)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)

                    Text(creditsPercentLabel)
                        .font(PiTypography.caption())
                        .fontWeight(.medium)
                        .foregroundStyle(PiColors.navyPrimary)
                }
                Spacer(minLength: DesignTokens.Space.s8)
                VStack(alignment: .trailing, spacing: DesignTokens.Space.s12) {
                    Text(statusLabel)
                        .font(PiTypography.caption())
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, DesignTokens.Space.s12)
                        .padding(.vertical, DesignTokens.Space.s8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(statusColor.opacity(0.12))
                        )
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(name), \(formattedSavedOfTarget), \(statusLabel), \(monthlyNeedLabel), \(creditsPercentLabel)"
        )
        .accessibilityHint("Opens goal detail")
        .accessibilityAddTraits(.isButton)
    }

    private var statusColor: Color {
        switch statusLabel {
        case "On track":
            return PiColors.positiveGreen
        case "Behind":
            return PiColors.behind
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: DesignTokens.Space.s12) {
        GoalCard(
            name: "Car",
            formattedSavedOfTarget: "₹60,000 of ₹13,10,796",
            statusLabel: "On track",
            monthlyNeedLabel: "Needs ₹26,058 a month",
            creditsPercentLabel: "60% of credits"
        )
        GoalCard(
            name: "Emergency Fund",
            formattedSavedOfTarget: "₹40,000 of ₹2,14,000",
            statusLabel: "Behind",
            monthlyNeedLabel: "Needs ₹14,500 a month",
            creditsPercentLabel: "40% of credits"
        )
    }
    .padding()
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
