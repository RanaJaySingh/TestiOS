import SwiftUI

/// Goals open-entry banner (frame 9b / PRD R9 / Spec BR-6) — Assign now treatment.
/// Visual restyle only (PIP-81); Assign now still opens existing credit entry.
struct OpenEntryBanner: View {
    let message: String
    var onAssignNow: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.s12) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8 / 2) {
                Text(CreditEntryService.openEntryBannerPrefix)
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(PiColors.navyPrimary)
                Text(message)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Space.s8)
            Button(action: onAssignNow) {
                Text(CreditEntryService.assignNowTitle)
                    .font(PiTypography.caption())
                    .fontWeight(.semibold)
                    .padding(.horizontal, DesignTokens.Space.s12)
                    .padding(.vertical, DesignTokens.Space.s8)
                    .foregroundStyle(Color.white)
                    .background(PiColors.navyPrimary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openEntryBanner.assignNow")
        }
        .padding(DesignTokens.Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PiColors.chipLightBlue)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
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
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
