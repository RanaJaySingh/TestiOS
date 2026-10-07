import SwiftUI

/// Individual goal card — name, saved amount, On track / Behind (frames 9 / 11).
struct GoalCard: View {
    let name: String
    let formattedSaved: String
    let statusLabel: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(formattedSaved)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 8)
            Text(statusLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(statusColor.opacity(0.12))
                )
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), saved \(formattedSaved), \(statusLabel)")
        .accessibilityHint("Opens goal detail")
        .accessibilityAddTraits(.isButton)
    }

    private var statusColor: Color {
        switch statusLabel {
        case "On track":
            return .green
        case "Behind":
            return .orange
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        GoalCard(name: "Car", formattedSaved: "₹60,000", statusLabel: "On track")
        GoalCard(name: "Emergency Fund", formattedSaved: "₹40,000", statusLabel: "Behind")
    }
    .padding()
}
