import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// Smoke / unit coverage for PIP-67 design tokens (Tech Spec §3.1 / §6.2).
final class DesignTokensTests: XCTestCase {

    func testNavyPrimaryAndDeepMatchApprovedRange() {
        XCTAssertEqual(DesignTokens.Navy.primary, 0x0A2A6B)
        XCTAssertEqual(DesignTokens.Navy.deep, 0x003A8C)
        XCTAssertEqual(DesignTokens.hexString(DesignTokens.Navy.primary), "#0A2A6B")
        XCTAssertEqual(DesignTokens.hexString(DesignTokens.Navy.deep), "#003A8C")
    }

    func testChipPositiveBehindDestructiveAndSurfacesExist() {
        XCTAssertEqual(DesignTokens.Chip.lightBlue, 0xD6E8FF)
        XCTAssertEqual(DesignTokens.Chip.lightBlueLabel, DesignTokens.Navy.primary)
        XCTAssertEqual(DesignTokens.Status.positiveGreen, 0x1B8A4A)
        XCTAssertEqual(DesignTokens.Status.behind, 0xE65100)
        XCTAssertEqual(DesignTokens.Status.destructive, 0xC62828)
        XCTAssertEqual(DesignTokens.Surface.card, 0xFFFFFF)
        XCTAssertEqual(DesignTokens.Surface.backgroundApp, 0xF5F7FB)
    }

    func testNoPurpleOrBrightBlueAccentSubstitution() {
        // Former AccentColor ≈ #006BE8 must not remain as navy primary.
        XCTAssertNotEqual(DesignTokens.Navy.primary, 0x006BE8)
        // Guard against common purple/indigo AI defaults.
        XCTAssertNotEqual(DesignTokens.Navy.primary, 0x7C3AED)
        XCTAssertNotEqual(DesignTokens.Navy.primary, 0x6366F1)
        XCTAssertNotEqual(DesignTokens.Surface.backgroundApp, 0xF7F4EF) // Android cream — not iOS target
    }

    func testCardRadiusInApprovedRangePrefer22() {
        XCTAssertEqual(DesignTokens.Radius.card, 22)
        XCTAssertGreaterThanOrEqual(DesignTokens.Radius.card, 20)
        XCTAssertLessThanOrEqual(DesignTokens.Radius.card, 24)
        XCTAssertEqual(DesignTokens.Radius.sheet, 22)
        XCTAssertEqual(DesignTokens.Radius.chip, 12)
    }

    func testSpacingScaleDocumented() {
        XCTAssertEqual(DesignTokens.Space.scale, [8, 12, 16, 20, 24, 28])
        XCTAssertEqual(DesignTokens.Space.s8, 8)
        XCTAssertEqual(DesignTokens.Space.s12, 12)
        XCTAssertEqual(DesignTokens.Space.s16, 16)
        XCTAssertEqual(DesignTokens.Space.s20, 20)
        XCTAssertEqual(DesignTokens.Space.s24, 24)
        XCTAssertEqual(DesignTokens.Space.s28, 28)
    }

    func testTypographyHierarchySizes() {
        XCTAssertEqual(DesignTokens.TypeSize.amountHero, 34)
        XCTAssertEqual(DesignTokens.TypeSize.title, 22)
        XCTAssertEqual(DesignTokens.TypeSize.body, 17)
        XCTAssertEqual(DesignTokens.TypeSize.caption, 13)
        XCTAssertGreaterThan(DesignTokens.TypeSize.amountHero, DesignTokens.TypeSize.title)
        XCTAssertGreaterThan(DesignTokens.TypeSize.title, DesignTokens.TypeSize.body)
        XCTAssertGreaterThan(DesignTokens.TypeSize.body, DesignTokens.TypeSize.caption)
    }

    func testSRGBComponentsForNavyPrimary() {
        let c = DesignTokens.sRGBComponents(hex: DesignTokens.Navy.primary)
        // #0A2A6B → 10, 42, 107
        XCTAssertEqual(c.red, 10.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(c.green, 42.0 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(c.blue, 107.0 / 255.0, accuracy: 0.0001)
    }
}
