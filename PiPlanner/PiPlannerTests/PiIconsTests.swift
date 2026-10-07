import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// Icon catalog + MainTab chrome contract (PIP-71 / Tech Spec §3.3 / §3.4 / R4–R5).
final class PiIconsTests: XCTestCase {

    func testSpec33MetaphorSFSymbols() {
        XCTAssertEqual(PiIcons.goalsTab, "target")
        XCTAssertEqual(PiIcons.goalsTabSelected, "flag.fill")
        XCTAssertEqual(PiIcons.historyTab, "clock")
        XCTAssertEqual(PiIcons.historyTabSelected, "clock.fill")
        XCTAssertEqual(PiIcons.askTab, "bubble.left.and.bubble.right")
        XCTAssertEqual(PiIcons.askTabSelected, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(PiIcons.settings, "gearshape")
        XCTAssertEqual(PiIcons.lock, "lock.fill")
        XCTAssertEqual(PiIcons.sync, "arrow.triangle.2.circlepath")
        XCTAssertEqual(PiIcons.transfer, "arrow.left.arrow.right")
        XCTAssertEqual(PiIcons.withdrawal, "arrow.down.circle")
        XCTAssertEqual(PiIcons.newCredit, "plus.circle")
    }

    func testCatalogHasNoEmojiAndCoversRequiredMetaphors() {
        let metaphors = Set(PiIcons.catalog.map(\.metaphor))
        for required in [
            "Goals tab", "History tab", "Ask tab",
            "Settings gear", "Lock (saved)", "Sync", "Transfer",
            "Withdrawal / down", "New credit / add"
        ] {
            XCTAssertTrue(metaphors.contains(required), "Missing metaphor \(required)")
        }
        for entry in PiIcons.catalog {
            XCTAssertFalse(entry.systemImage.isEmpty)
            // No emoji / non-ASCII glyph placeholders (Android-style text glyphs).
            XCTAssertTrue(
                entry.systemImage.unicodeScalars.allSatisfy { $0.isASCII },
                "SF Symbol name must be ASCII, got \(entry.systemImage)"
            )
        }
    }

    func testMainTabChromeExactlyThreeGoalsHistoryAskInOrder() {
        XCTAssertEqual(MainTabChrome.tabCount, 3)
        XCTAssertEqual(MainTabChrome.titlesInOrder, ["Goals", "History", "Ask"])
        XCTAssertEqual(MainTabChrome.Tab.allCases.map(\.rawValue), [0, 1, 2])
        XCTAssertFalse(MainTabChrome.titlesInOrder.contains("Settings"))
    }

    func testMainTabChromeSelectedVsUnselectedIcons() {
        XCTAssertEqual(MainTabChrome.Tab.goals.systemImage(selected: false), PiIcons.goalsTab)
        XCTAssertEqual(MainTabChrome.Tab.goals.systemImage(selected: true), PiIcons.goalsTabSelected)
        XCTAssertEqual(MainTabChrome.Tab.history.systemImage(selected: false), PiIcons.historyTab)
        XCTAssertEqual(MainTabChrome.Tab.history.systemImage(selected: true), PiIcons.historyTabSelected)
        XCTAssertEqual(MainTabChrome.Tab.ask.systemImage(selected: false), PiIcons.askTab)
        XCTAssertEqual(MainTabChrome.Tab.ask.systemImage(selected: true), PiIcons.askTabSelected)
        // Selected weight differs where SF provides a filled variant.
        XCTAssertNotEqual(
            MainTabChrome.Tab.history.systemImage,
            MainTabChrome.Tab.history.selectedSystemImage
        )
        XCTAssertNotEqual(
            MainTabChrome.Tab.ask.systemImage,
            MainTabChrome.Tab.ask.selectedSystemImage
        )
    }

    func testSelectedTabTintUsesNavyPrimaryToken() {
        XCTAssertEqual(MainTabChrome.selectedTintHex, DesignTokens.Navy.primary)
        XCTAssertEqual(DesignTokens.hexString(MainTabChrome.selectedTintHex), "#0A2A6B")
        // Guard against former bright AccentColor.
        XCTAssertNotEqual(MainTabChrome.selectedTintHex, 0x006BE8)
    }

    func testTabAccessibilityIdentifiersStable() {
        XCTAssertEqual(MainTabChrome.Tab.goals.accessibilityIdentifier, "tab.goals")
        XCTAssertEqual(MainTabChrome.Tab.history.accessibilityIdentifier, "tab.history")
        XCTAssertEqual(MainTabChrome.Tab.ask.accessibilityIdentifier, "tab.ask")
    }

    func testHistoryServiceUsesCatalogForSpec33Types() {
        XCTAssertEqual(HistoryService.systemImageName(for: .newCredit), PiIcons.newCredit)
        XCTAssertEqual(HistoryService.systemImageName(for: .transfer), PiIcons.transfer)
        XCTAssertEqual(HistoryService.systemImageName(for: .withdrawal), PiIcons.withdrawal)
    }
}
