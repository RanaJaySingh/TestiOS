import SwiftUI

/// Paytm-like bottom-sheet chrome — top radius, handle, title / helper spacing (Tech Spec §3.5).
///
/// Platform `.sheet` presentation stays; wrap sheet *content* with this chrome.
struct PiSheet<Content: View>: View {
    let title: String
    var helper: String? = nil
    private let content: Content

    init(
        title: String,
        helper: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(PiColors.surfaceCard)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: DesignTokens.Radius.sheet,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: DesignTokens.Radius.sheet
                ),
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("components.piSheet")
    }

    private var handle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, DesignTokens.Space.s12)
            .padding(.bottom, DesignTokens.Space.s8)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text(title)
                .font(PiTypography.title())
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("components.piSheet.title")

            if let helper, !helper.isEmpty {
                Text(helper)
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("components.piSheet.helper")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Space.s20)
        .padding(.bottom, DesignTokens.Space.s16)
    }
}

extension View {
    /// Apply shared sheet chrome (title + optional helper) around existing sheet body content.
    func piSheetChrome(title: String, helper: String? = nil) -> some View {
        PiSheet(title: title, helper: helper) {
            self
        }
    }
}

#Preview("PiSheet chrome") {
    ZStack(alignment: .bottom) {
        PiColors.backgroundApp.ignoresSafeArea()
        PiSheet(
            title: "Allow balance checks?",
            helper: "Asked for the account where credits arrive."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                Text("Sheet body rows go here.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
                PrimaryCTA(title: "Yes", action: {})
                SecondaryCTA(title: "No I’ll update myself", style: .text, action: {})
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
        .padding(.top, 80)
    }
    .piPlannerTheme()
}
