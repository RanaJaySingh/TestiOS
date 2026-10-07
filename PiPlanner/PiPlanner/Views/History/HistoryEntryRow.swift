import SwiftUI

/// Single History list row — type icon/label, lock when saved, amount, date (frame 12).
struct HistoryEntryRow: View {
    let typeLabel: String
    let systemImageName: String
    let subtitle: String?
    let dateLabel: String
    let amountLabel: String
    let showsLock: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImageName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(typeLabel)
                        .font(.body)
                        .fontWeight(.semibold)
                    if showsLock {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Locked")
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(amountLabel)
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Locked opening") {
    HistoryEntryRow(
        typeLabel: "Opening balance",
        systemImageName: "banknote",
        subtitle: nil,
        dateLabel: "14 Nov 2023, 5:46 AM",
        amountLabel: "₹1,00,000",
        showsLock: true
    )
    .padding()
}

#Preview("Open credit") {
    HistoryEntryRow(
        typeLabel: "New credit",
        systemImageName: "plus.circle",
        subtitle: "Assign now",
        dateLabel: "14 Nov 2023, 6:00 AM",
        amountLabel: "₹10,000",
        showsLock: false
    )
    .padding()
}
