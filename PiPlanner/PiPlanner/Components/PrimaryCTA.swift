import SwiftUI

/// Filled navy primary button (PRD §9 / Tech Spec §3.5 `PrimaryButton`).
///
/// Enabled: navy fill + white label. Disabled: muted navy, non-interactive.
struct PrimaryCTA: View {
    let title: String
    var isEnabled: Bool = true
    var accessibilityIdentifier: String = "components.primaryCTA"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
                .foregroundStyle(Color.white.opacity(isEnabled ? 1 : 0.85))
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var background: some ShapeStyle {
        isEnabled ? PiColors.navyPrimary : PiColors.navyPrimary.opacity(0.55)
    }
}

#Preview("PrimaryCTA states") {
    VStack(spacing: DesignTokens.Space.s16) {
        PrimaryCTA(title: "Set up savings", isEnabled: true, action: {})
        PrimaryCTA(title: "Continue", isEnabled: false, action: {})
    }
    .padding(DesignTokens.Space.s20)
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
