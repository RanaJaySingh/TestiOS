import SwiftUI

/// Balance card on Goals tab — total savings + Sync / Update balance CTA (frames 9 / 9b / 9c).
struct BalanceCard: View {
    let formattedTotal: String
    let accountSubtitle: String?
    let actionTitle: String
    /// When false, Sync/Update is disabled (open credit pending — BR-6 / R9).
    var actionEnabled: Bool = true
    var onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total savings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formattedTotal)
                .font(.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .accessibilityIdentifier("goals.balance.total")

            if let accountSubtitle {
                Text(accountSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("goals.balance.account")
            }

            Button(action: onAction) {
                Text(actionTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!actionEnabled)
            .accessibilityIdentifier("goals.balance.action")
            .accessibilityLabel(actionTitle)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    BalanceCard(
        formattedTotal: "₹1,00,000",
        accountSubtitle: "HDFC ••4821",
        actionTitle: "Sync",
        onAction: {}
    )
    .padding()
}
