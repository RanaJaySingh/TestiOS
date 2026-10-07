#if canImport(SwiftUI)
import SwiftUI

extension Color {
    /// Build an opaque sRGB `Color` from a `0xRRGGBB` design-token hex.
    public init(piHex hex: UInt32) {
        let c = DesignTokens.sRGBComponents(hex: hex)
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }
}

/// SwiftUI colours mirrored from `DesignTokens` — prefer these over system `.green` / bright accent.
public enum PiColors {
    public static let navyPrimary = Color(piHex: DesignTokens.Navy.primary)
    public static let navyDeep = Color(piHex: DesignTokens.Navy.deep)
    public static let chipLightBlue = Color(piHex: DesignTokens.Chip.lightBlue)
    public static let chipLightBlueLabel = Color(piHex: DesignTokens.Chip.lightBlueLabel)
    public static let positiveGreen = Color(piHex: DesignTokens.Status.positiveGreen)
    public static let behind = Color(piHex: DesignTokens.Status.behind)
    public static let destructive = Color(piHex: DesignTokens.Status.destructive)
    public static let surfaceCard = Color(piHex: DesignTokens.Surface.card)
    public static let backgroundApp = Color(piHex: DesignTokens.Surface.backgroundApp)
}

/// Convenience font helpers matching `DesignTokens.TypeSize` hierarchy.
public enum PiTypography {
    public static func amountHero() -> Font { .system(size: DesignTokens.TypeSize.amountHero, weight: .bold) }
    public static func title() -> Font { .system(size: DesignTokens.TypeSize.title, weight: .semibold) }
    public static func body() -> Font { .system(size: DesignTokens.TypeSize.body, weight: .regular) }
    public static func caption() -> Font { .system(size: DesignTokens.TypeSize.caption, weight: .regular) }
}
#endif
