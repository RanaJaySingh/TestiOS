#if canImport(SwiftUI)
import SwiftUI

/// App theme entry point (Tech Spec §4.1).
/// Applies light appearance and navy primary tint without restyling individual screens.
public enum PiTheme {
    /// Preferred colour scheme for visual parity — light only (design artifact).
    public static let preferredColorScheme: ColorScheme = .light

    /// Primary tint / accent — maps to `DesignTokens.Navy.primary` (and AccentColor asset).
    public static let accent: Color = PiColors.navyPrimary
}

extension View {
    /// Wire shared theme: light appearance + navy accent tint.
    /// Does not alter layout or product behaviour — tint/chrome only.
    public func piPlannerTheme() -> some View {
        self
            .preferredColorScheme(PiTheme.preferredColorScheme)
            .tint(PiTheme.accent)
    }
}
#endif
