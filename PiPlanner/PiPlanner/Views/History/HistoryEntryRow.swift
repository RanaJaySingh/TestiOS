import SwiftUI

/// Single History list row — type icon/label, lock when saved, amount, date (frame 12 / PIP-91).
///
/// Visual-only: consumes `DesignTokens` / `PiColors` / `PiTypography` / `PiIcons` / `PiCard`.
/// Open vs locked chrome differs; product destination logic stays in `HistoryTabView`.
struct HistoryEntryRow: View {
    let typeLabel: String
    let systemImageName: String
    let subtitle: String?
    let dateLabel: String
    let amountLabel: String
    let showsLock: Bool

    /// Open (unlocked) credit rows get Assign-now accent chrome; locked rows show lock + quieter well.
    private var isOpenChrome: Bool { !showsLock }

    var body: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            HStack(alignment: .top, spacing: DesignTokens.Space.s12) {
                typeIconWell
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    HStack(spacing: DesignTokens.Space.s8) {
                        Text(typeLabel)
                            .font(PiTypography.body())
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        if showsLock {
                            Image(systemName: PiIcons.lock)
                                .font(.system(size: DesignTokens.TypeSize.caption, weight: .semibold))
                                .foregroundStyle(PiColors.navyPrimary.opacity(0.72))
                                .accessibilityLabel("Locked")
                                .accessibilityIdentifier("history.row.lock")
                        }
                    }
                    if let subtitle, !subtitle.isEmpty {
                        subtitleLabel(subtitle)
                    }
                    Text(dateLabel)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: DesignTokens.Space.s8)

                Text(amountLabel)
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(isOpenChrome ? PiColors.navyPrimary : Color.primary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .overlay(alignment: .leading) {
            if isOpenChrome {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(PiColors.navyPrimary)
                    .frame(width: 3)
                    .padding(.vertical, DesignTokens.Space.s8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var typeIconWell: some View {
        Image(systemName: systemImageName)
            .font(.system(size: DesignTokens.TypeSize.body, weight: .semibold))
            .foregroundStyle(isOpenChrome ? PiColors.navyPrimary : PiColors.navyPrimary.opacity(0.72))
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(isOpenChrome ? PiColors.chipLightBlue : PiColors.chipLightBlue.opacity(0.55))
            )
    }

    @ViewBuilder
    private func subtitleLabel(_ text: String) -> some View {
        if isOpenChrome {
            Text(text)
                .font(PiTypography.caption())
                .fontWeight(.semibold)
                .foregroundStyle(PiColors.chipLightBlueLabel)
                .padding(.horizontal, DesignTokens.Space.s8)
                .padding(.vertical, 4)
                .background(PiColors.chipLightBlue.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
                .accessibilityIdentifier("history.row.assignNow")
        } else {
            Text(text)
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

#Preview("Locked opening") {
    ZStack {
        PiColors.backgroundApp.ignoresSafeArea()
        HistoryEntryRow(
            typeLabel: "Opening balance",
            systemImageName: "banknote",
            subtitle: nil,
            dateLabel: "14 Nov 2023, 5:46 AM",
            amountLabel: "₹1,00,000",
            showsLock: true
        )
        .padding(DesignTokens.Space.s16)
    }
    .piPlannerTheme()
}

#Preview("Open credit") {
    ZStack {
        PiColors.backgroundApp.ignoresSafeArea()
        HistoryEntryRow(
            typeLabel: "New credit",
            systemImageName: PiIcons.newCredit,
            subtitle: "Assign now",
            dateLabel: "14 Nov 2023, 6:00 AM",
            amountLabel: "₹10,000",
            showsLock: false
        )
        .padding(DesignTokens.Space.s16)
    }
    .piPlannerTheme()
}

#Preview("Locked transfer") {
    ZStack {
        PiColors.backgroundApp.ignoresSafeArea()
        HistoryEntryRow(
            typeLabel: "Transfer",
            systemImageName: PiIcons.transfer,
            subtitle: "Emergency → Car · ₹5,000",
            dateLabel: "5 Oct 2026, 7:42 PM",
            amountLabel: "₹5,000",
            showsLock: true
        )
        .padding(DesignTokens.Space.s16)
    }
    .piPlannerTheme()
}
