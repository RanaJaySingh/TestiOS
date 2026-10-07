import SwiftUI

/// Soft light-blue chip (Ask suggestions, Transfer ₹ amounts) — Tech Spec §3.5.
///
/// Fill / label from `PiColors.chipLightBlue` / `chipLightBlueLabel`.
/// Selected: navy stroke + semibold label. Unselected: fill only.
struct LightBlueChip: View {
    let title: String
    var isSelected: Bool = false
    var accessibilityIdentifier: String = "components.lightBlueChip"
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var label: some View {
        Text(title)
            .font(PiTypography.caption())
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(PiColors.chipLightBlueLabel)
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(PiColors.chipLightBlue.opacity(isSelected ? 1 : 0.72))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                    .strokeBorder(
                        isSelected ? PiColors.navyPrimary : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }
}

#Preview("LightBlueChip states") {
    HStack(spacing: DesignTokens.Space.s12) {
        LightBlueChip(title: "₹1,000", isSelected: false, action: {})
        LightBlueChip(title: "₹5,000", isSelected: true, action: {})
        LightBlueChip(title: "₹10,000", isSelected: false, action: {})
    }
    .padding(DesignTokens.Space.s20)
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
