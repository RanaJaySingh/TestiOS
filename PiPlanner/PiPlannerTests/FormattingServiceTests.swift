import XCTest
#if canImport(PiPlannerCore)
@testable import PiPlannerCore
#elseif canImport(PiPlanner)
@testable import PiPlanner
#endif

final class FormattingServiceTests: XCTestCase {
    private var formatter: FormattingService!

    override func setUp() {
        super.setUp()
        formatter = FormattingService()
    }

    override func tearDown() {
        formatter = nil
        super.tearDown()
    }

    func testFormatsZeroPaisaAsRupeeZero() {
        XCTAssertEqual(formatter.formatINR(paisa: 0), "₹0")
    }

    func testFormatsSmallAmountWithoutGrouping() {
        // 999 rupees = 99_900 paisa
        XCTAssertEqual(formatter.formatINR(paisa: 99_900), "₹999")
    }

    func testFormatsThousandsWithIndianGrouping() {
        // 1,000 rupees = 100_000 paisa
        XCTAssertEqual(formatter.formatINR(paisa: 100_000), "₹1,000")
    }

    func testFormatsLakhWithIndianGrouping() {
        // 1,00,000 rupees = 10_000_000 paisa (PRD R20 / Spec BR-10)
        XCTAssertEqual(formatter.formatINR(paisa: 10_000_000), "₹1,00,000")
    }

    func testFormatsExampleThirteenLakh() {
        // ₹13,10,796 → 1_310_796 rupees = 131_079_600 paisa
        XCTAssertEqual(formatter.formatINR(paisa: 131_079_600), "₹13,10,796")
    }

    func testFormatsCroreWithIndianGrouping() {
        // 1,00,00,000 rupees
        XCTAssertEqual(formatter.formatINR(paisa: 1_000_000_000), "₹1,00,00,000")
    }

    func testDropsPaiseFractionByDefault() {
        // 100 rupees + 50 paisa → display rupees only
        XCTAssertEqual(formatter.formatINR(paisa: 10_050), "₹100")
    }

    func testFormatsNegativeAmounts() {
        XCTAssertEqual(formatter.formatINR(paisa: -10_000_000), "-₹1,00,000")
    }

    func testFormatsDemoPersonaBalances() {
        // HDFC ₹1,00,000 and SBI ₹72,000 from Spec persona
        XCTAssertEqual(formatter.formatINR(paisa: 10_000_000), "₹1,00,000")
        XCTAssertEqual(formatter.formatINR(paisa: 7_200_000), "₹72,000")
    }
}
