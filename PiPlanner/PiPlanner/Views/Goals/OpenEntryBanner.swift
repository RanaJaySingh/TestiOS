import SwiftUI

/// Goals open-entry banner (frame 9b / PRD R9 / Spec BR-6).
struct OpenEntryBanner: View {
    let message: String
    var onAssignNow: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(CreditEntryService.openEntryBannerPrefix)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(CreditEntryService.assignNowTitle, action: onAssignNow)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("openEntryBanner.assignNow")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("openEntryBanner")
    }

    /// Convenience using shared copy helper.
    static func forEntry(
        _ entry: HistoryEntry,
        formatting: any FormattingServicing = FormattingService(),
        onAssignNow: @escaping () -> Void
    ) -> OpenEntryBanner {
        OpenEntryBanner(
            message: CreditEntryService.openEntryBannerMessage(
                for: entry,
                formatting: formatting
            ),
            onAssignNow: onAssignNow
        )
    }
}

#Preview {
    OpenEntryBanner(
        message: "New credit found ₹10,000. Assign now",
        onAssignNow: {}
    )
    .padding()
}
