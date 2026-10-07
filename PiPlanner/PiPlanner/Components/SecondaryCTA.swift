import SwiftUI

/// Secondary CTA — outline or text (PRD §9 / Tech Spec §3.5 `SecondaryButton`).
enum SecondaryCTAStyle: Equatable {
    /// Navy stroke, transparent fill.
    case outline
    /// Text-only navy label (Cancel / Use a form).
    case text
}

struct SecondaryCTA: View {
    let title: String
    var style: SecondaryCTAStyle = .outline
    var isEnabled: Bool = true
    var accessibilityIdentifier: String = "components.secondaryCTA"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PiTypography.body())
                .fontWeight(style == .outline ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Space.s12)
                .foregroundStyle(PiColors.navyPrimary.opacity(isEnabled ? 1 : 0.45))
                .background(labelBackground)
                .overlay(outlineOverlay)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private var labelBackground: some View {
        switch style {
        case .outline:
            PiColors.surfaceCard
        case .text:
            Color.clear
        }
    }

    @ViewBuilder
    private var outlineOverlay: some View {
        if style == .outline {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                .strokeBorder(PiColors.navyPrimary.opacity(isEnabled ? 1 : 0.35), lineWidth: 1.5)
        }
    }
}

#Preview("SecondaryCTA styles") {
    VStack(spacing: DesignTokens.Space.s16) {
        SecondaryCTA(title: "Cancel", style: .outline, action: {})
        SecondaryCTA(title: "Use a form", style: .text, action: {})
        SecondaryCTA(title: "No I’ll update myself", style: .text, isEnabled: false, action: {})
    }
    .padding(DesignTokens.Space.s20)
    .background(PiColors.backgroundApp)
    .piPlannerTheme()
}
