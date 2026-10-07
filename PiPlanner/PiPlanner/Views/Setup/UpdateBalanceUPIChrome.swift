import SwiftUI

/// Shared Paytm-like chrome for Update balance / UPI Demo (PIP-77 · PRD R8 · frames 4 / 4a–4e / 11a–11c).
/// Visual helpers only — no ViewModel or product behaviour.

// MARK: - Choice rows (frames 4 / 11a)

struct UpdateBalanceChoiceRow: View {
    let title: String
    let subtitle: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Space.s12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PiColors.navyPrimary.opacity(isEnabled ? 1 : 0.45))
                        .frame(width: 28, alignment: .center)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.45))
                    Text(subtitle)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary.opacity(isEnabled ? 1 : 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DesignTokens.Space.s8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PiColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
        .accessibilityIdentifier(accessibilityIdentifier ?? "updateBalance.choiceRow")
    }
}

// MARK: - Demo badge + bank line (frame 4b / 11c)

struct UPIDemoBadge: View {
    var body: some View {
        Text("DEMO")
            .font(PiTypography.caption())
            .fontWeight(.bold)
            .tracking(0.6)
            .foregroundStyle(PiColors.chipLightBlueLabel)
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(PiColors.chipLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            .accessibilityLabel("Demo")
            .accessibilityIdentifier("upi.demoBadge")
    }
}

struct UPIBankMaskedLine: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PiTypography.body())
            .fontWeight(.medium)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .accessibilityLabel("Bank account \(title)")
            .accessibilityIdentifier("upi.bankMaskedLine")
    }
}

// MARK: - PIN dots + mock pad

struct UPIPinDots: View {
    let filledCount: Int
    var showsError: Bool = false
    private let total = 4

    var body: some View {
        HStack(spacing: DesignTokens.Space.s16) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .strokeBorder(strokeColor, lineWidth: 1.5)
                    .background(
                        Circle().fill(index < filledCount ? fillColor : Color.clear)
                    )
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PIN entered \(min(filledCount, total)) of \(total) digits")
        .accessibilityIdentifier("upi.pinDots")
    }

    private var strokeColor: Color {
        showsError ? PiColors.destructive : Color.secondary
    }

    private var fillColor: Color {
        showsError ? PiColors.destructive : PiColors.navyPrimary
    }
}

struct UPIMockPad: View {
    var isEnabled: Bool = true
    var onDigit: (String) -> Void
    var onDelete: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: DesignTokens.Space.s12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: DesignTokens.Space.s12) {
                    ForEach(row, id: \.self) { key in
                        padKey(key)
                    }
                }
            }
        }
        .padding(DesignTokens.Space.s12)
        .background(PiColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upi.mockPad")
    }

    @ViewBuilder
    private func padKey(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        } else {
            Button {
                if key == "⌫" {
                    onDelete()
                } else {
                    onDigit(key)
                }
            } label: {
                Text(key)
                    .font(PiTypography.title())
                    .fontWeight(.medium)
                    .foregroundStyle(PiColors.navyPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(PiColors.backgroundApp)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .accessibilityLabel(key == "⌫" ? "Delete" : key)
        }
    }
}

#Preview("Choice rows") {
    VStack(spacing: DesignTokens.Space.s12) {
        UpdateBalanceChoiceRow(
            title: "Manually",
            subtitle: "Type the opening balance",
            systemImage: "pencil",
            action: {}
        )
        UpdateBalanceChoiceRow(
            title: "Balance sync",
            subtitle: "Check with demo UPI PIN",
            systemImage: PiIcons.sync,
            action: {}
        )
    }
    .padding(DesignTokens.Space.s20)
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}

#Preview("UPI pad") {
    VStack(spacing: DesignTokens.Space.s20) {
        UPIDemoBadge()
        UPIBankMaskedLine(title: "HDFC ••4821")
        UPIPinDots(filledCount: 2)
        UPIMockPad(onDigit: { _ in }, onDelete: {})
    }
    .padding(DesignTokens.Space.s20)
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
