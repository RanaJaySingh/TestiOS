import SwiftUI

/// Goals home quick-action chip row — Sync/Update · New goal · Transfer · History (PIP-81 / §3.5).
/// Wires existing destinations only; no new product flows.
struct QuickActionRow<TransferCell: View>: View {
    let balanceActionTitle: String
    var balanceActionEnabled: Bool = true
    var onBalanceAction: () -> Void
    var onNewGoal: () -> Void
    var onHistory: () -> Void
    @ViewBuilder var transferCell: () -> TransferCell

    var body: some View {
        HStack(spacing: DesignTokens.Space.s8) {
            QuickActionCell(
                title: balanceActionTitle,
                systemImage: PiIcons.sync,
                enabled: balanceActionEnabled,
                accessibilityIdentifier: "goals.quickAction.balance",
                action: onBalanceAction
            )
            QuickActionCell(
                title: "New goal",
                systemImage: PiIcons.newCredit,
                accessibilityIdentifier: "goals.quickAction.newGoal",
                action: onNewGoal
            )
            transferCell()
                .frame(maxWidth: .infinity)
            QuickActionCell(
                title: "History",
                systemImage: PiIcons.historyTab,
                accessibilityIdentifier: "goals.quickAction.history",
                action: onHistory
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("goals.quickActions")
    }
}

/// Single quick-action chip (icon + label) shared by row slots.
struct QuickActionCell: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    var accessibilityIdentifier: String
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
            } else {
                label
                    .opacity(enabled ? 1 : 0.45)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }

    private var label: some View {
        VStack(spacing: DesignTokens.Space.s8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PiColors.navyPrimary.opacity(enabled ? 1 : 0.4))
                .frame(width: 44, height: 44)
                .background(PiColors.chipLightBlue.opacity(enabled ? 1 : 0.55))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            Text(title)
                .font(PiTypography.caption())
                .fontWeight(.medium)
                .foregroundStyle(PiColors.navyPrimary.opacity(enabled ? 1 : 0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    QuickActionRow(
        balanceActionTitle: "Sync",
        onBalanceAction: {},
        onNewGoal: {},
        onHistory: {}
    ) {
        QuickActionCell(
            title: "Transfer",
            systemImage: PiIcons.transfer,
            accessibilityIdentifier: "goals.quickAction.transfer",
            action: {}
        )
    }
    .padding()
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
