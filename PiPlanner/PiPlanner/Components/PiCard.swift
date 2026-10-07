import SwiftUI

/// White content card — soft Paytm-like elevation (PRD R2 / Tech Spec §3.5).
///
/// Consumes `DesignTokens.Radius.card` (22) and `PiColors.surfaceCard`.
/// Soft single-layer shadow only — not heavy multi-layer stacks.
struct PiCard<Content: View>: View {
    private let padding: Double
    private let content: Content

    init(
        padding: Double = DesignTokens.Space.s16,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PiColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous))
            .shadow(
                color: Color.black.opacity(Self.softShadowOpacity),
                radius: Self.softShadowRadius,
                x: 0,
                y: Self.softShadowY
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("components.piCard")
    }

    /// Soft card elevation — single layer (AC: not heavy multi-layer).
    static let softShadowOpacity: Double = 0.08
    static let softShadowRadius: Double = 8
    static let softShadowY: Double = 4
}

#Preview("PiCard") {
    ZStack {
        PiColors.backgroundApp.ignoresSafeArea()
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Card title")
                    .font(PiTypography.title())
                Text("White surface, radius 22, soft shadow.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Space.s20)
    }
    .piPlannerTheme()
}
