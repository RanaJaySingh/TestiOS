import SwiftUI

/// Navy balance card on Goals tab — total savings + last-synced line + Sync / Update CTA (frames 9 / 9b / 9c).
/// Visual restyle only (PIP-81 / Tech Spec §3.5 NavyBalanceCard); callbacks unchanged.
struct BalanceCard: View {
    let formattedTotal: String
    let accountSubtitle: String?
    /// "Last synced today, 7:42 pm" / "Last updated …"
    let lastActivityLine: String
    let actionTitle: String
    /// When false, Sync/Update is disabled (open credit pending — BR-6 / R9).
    var actionEnabled: Bool = true
    var onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("Total savings")
                .font(PiTypography.caption())
                .foregroundStyle(Color.white.opacity(0.78))

            Text(formattedTotal)
                .font(PiTypography.amountHero())
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .accessibilityIdentifier("goals.balance.total")

            if let accountSubtitle {
                Text(accountSubtitle)
                    .font(PiTypography.caption())
                    .foregroundStyle(Color.white.opacity(0.78))
                    .accessibilityIdentifier("goals.balance.account")
            }

            Text(lastActivityLine)
                .font(PiTypography.caption())
                .foregroundStyle(Color.white.opacity(0.72))
                .accessibilityIdentifier("goals.balance.lastActivity")

            Button(action: onAction) {
                Text(actionTitle)
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Space.s12)
                    .foregroundStyle(actionEnabled ? PiColors.navyPrimary : PiColors.navyPrimary.opacity(0.55))
                    .background(Color.white.opacity(actionEnabled ? 1 : 0.72))
                    .clipShape(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!actionEnabled)
            .accessibilityIdentifier("goals.balance.action")
            .accessibilityLabel(actionTitle)
        }
        .padding(DesignTokens.Space.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(navyBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var navyBackground: some View {
        LinearGradient(
            colors: [PiColors.navyPrimary, PiColors.navyDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("Consent On — Sync") {
    BalanceCard(
        formattedTotal: "₹1,00,000",
        accountSubtitle: "HDFC ••4821",
        lastActivityLine: "Last synced today, 7:42 pm",
        actionTitle: "Sync",
        onAction: {}
    )
    .padding()
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}

#Preview("Consent Off — Update") {
    BalanceCard(
        formattedTotal: "₹1,00,000",
        accountSubtitle: "HDFC ••4821",
        lastActivityLine: "Last updated today, 7:42 pm",
        actionTitle: "Update balance",
        onAction: {}
    )
    .padding()
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
