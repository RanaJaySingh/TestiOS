import SwiftUI

/// Ask proposal card — Edit / Confirm + “Checked by PiPlanner. Estimate.” (frame 19b).
struct ProposalCard: View {
    let title: String
    let summary: String
    let checkedByLabel: String
    var onEdit: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ask.proposal.title")

            Text(summary)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ask.proposal.summary")

            Text(checkedByLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(checkedByLabel)
                .accessibilityIdentifier("ask.proposal.checkedBy")

            HStack(spacing: 12) {
                Button("Edit") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("ask.proposal.edit")

                Button("Confirm") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ask.proposal.confirm")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ask.proposal.card")
    }
}

#Preview {
    ProposalCard(
        title: "Suggested transfer",
        summary: "Car → Emergency Fund · ₹5,000",
        checkedByLabel: StubGrokService.checkedByLabel,
        onEdit: {},
        onConfirm: {}
    )
    .padding()
}
