import Foundation

/// Shared PiPlanner design tokens (Tech Spec §3.1 / PRD R1–R2).
///
/// Single module for navy, chips, status colours, surfaces, radii, spacing, and type sizes.
/// Later visual tickets (PIP-69+) should import these instead of ad hoc colours or padding.
///
/// Spacing scale (documented): **8 / 12 / 16 / 20 / 24 / 28**.
/// Card radius: **22** (within approved 20–24).
public enum DesignTokens {

    // MARK: - Colour hex (sRGB, 0xRRGGBB)

    /// Navy brand stops within approved range `#0A2A6B`–`#003A8C` (PRD R1 / A1).
    public enum Navy {
        /// Primary navy — balance card fill / primary CTA / accent tint (`#0A2A6B`).
        public static let primary: UInt32 = 0x0A2A6B
        /// Deep navy — gradient / end accent within approved range (`#003A8C`).
        public static let deep: UInt32 = 0x003A8C
    }

    public enum Chip {
        /// Soft light-blue chip fill (Ask suggestions, Transfer ₹ chips).
        public static let lightBlue: UInt32 = 0xD6E8FF
        /// Readable dark label on light-blue chips (navy primary).
        public static let lightBlueLabel: UInt32 = Navy.primary
    }

    public enum Status {
        /// Positive green for `+₹` / On track.
        public static let positiveGreen: UInt32 = 0x1B8A4A
        /// Behind / warning amber (goal status).
        public static let behind: UInt32 = 0xE65100
        /// Destructive / error red (delete, PIN error).
        public static let destructive: UInt32 = 0xC62828
    }

    public enum Surface {
        /// White card surface.
        public static let card: UInt32 = 0xFFFFFF
        /// App background — light (not cream / green theme).
        public static let backgroundApp: UInt32 = 0xF5F7FB
    }

    // MARK: - Radii (points)

    public enum Radius {
        /// Primary content cards — prefer 22 within 20–24 (A3).
        public static let card: Double = 22
        /// Chips / status pills.
        public static let chip: Double = 12
        /// Bottom sheet top corners.
        public static let sheet: Double = 22
    }

    // MARK: - Spacing scale (points): 8 / 12 / 16 / 20 / 24 / 28

    public enum Space {
        public static let s8: Double = 8
        public static let s12: Double = 12
        public static let s16: Double = 16
        public static let s20: Double = 20
        public static let s24: Double = 24
        public static let s28: Double = 28

        /// Canonical scale for documentation and smoke tests.
        public static let scale: [Double] = [s8, s12, s16, s20, s24, s28]
    }

    // MARK: - Typography sizes (platform fonts OK — hierarchy only)

    public enum TypeSize {
        /// Emphasized ₹ amount (balance card, goal detail).
        public static let amountHero: Double = 34
        public static let title: Double = 22
        public static let body: Double = 17
        public static let caption: Double = 13
    }

    // MARK: - Hex helpers (testable without UIKit/SwiftUI)

    /// Unpack `0xRRGGBB` into sRGB components in `0...1`.
    public static func sRGBComponents(hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return (r, g, b)
    }

    /// `#RRGGBB` string for a token hex value.
    public static func hexString(_ hex: UInt32) -> String {
        String(format: "#%06X", hex & 0xFFFFFF)
    }
}
