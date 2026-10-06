import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

/// Xcode test-host smoke entry. Detailed cases live in sibling XCTest files
/// and are also exercised via the PiPlannerCore Swift package on CI/Linux.
final class PiPlannerTests: XCTestCase {
    func testFormattingServiceIsAvailableInAppTarget() {
        let formatted = FormattingService().formatINR(paisa: 10_000_000)
        XCTAssertEqual(formatted, "₹1,00,000")
    }
}
