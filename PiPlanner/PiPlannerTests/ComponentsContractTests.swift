import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// Linux-friendly contract smoke for PIP-69 — token values Components consume (Tech Spec §3.5 / §6.2).
/// SwiftUI views themselves live under `Components/` (app target / Xcode previews).
final class ComponentsContractTests: XCTestCase {

    func testPiCardConsumesApprovedCardRadius() {
        XCTAssertEqual(DesignTokens.Radius.card, 22)
        XCTAssertGreaterThanOrEqual(DesignTokens.Radius.card, 20)
        XCTAssertLessThanOrEqual(DesignTokens.Radius.card, 24)
    }

    func testChipAndSheetRadiiForSharedChrome() {
        XCTAssertEqual(DesignTokens.Radius.chip, 12)
        XCTAssertEqual(DesignTokens.Radius.sheet, 22)
    }

    func testPrimaryAndChipSurfacesFromTokens() {
        XCTAssertEqual(DesignTokens.Navy.primary, 0x0A2A6B)
        XCTAssertEqual(DesignTokens.Chip.lightBlue, 0xD6E8FF)
        XCTAssertEqual(DesignTokens.Chip.lightBlueLabel, DesignTokens.Navy.primary)
        XCTAssertEqual(DesignTokens.Surface.card, 0xFFFFFF)
    }

    func testSpacingUsedByComponentPadding() {
        XCTAssertEqual(DesignTokens.Space.s8, 8)
        XCTAssertEqual(DesignTokens.Space.s12, 12)
        XCTAssertEqual(DesignTokens.Space.s16, 16)
        XCTAssertEqual(DesignTokens.Space.s20, 20)
        XCTAssertEqual(DesignTokens.Space.s28, 28)
    }
}
