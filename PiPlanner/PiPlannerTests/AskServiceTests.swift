import XCTest
@testable import PiPlannerCore

final class AskServiceTests: XCTestCase {
    private let formatting = FormattingService()
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    func testSuggestionChipsMatchDesign() {
        XCTAssertEqual(AskService.suggestionChips.count, 2)
        XCTAssertTrue(AskService.suggestionChips[0].contains("split"))
        XCTAssertTrue(AskService.suggestionChips[1].lowercased().contains("inflation"))
        XCTAssertEqual(AskService.askStarters, AskService.suggestionChips)
    }

    func testPlainAnswerIncludesEngineNumbers() {
        let engine = AskEngineContext(goals: sampleGoals(), totalSavingsPaisa: 10_000_000)
        let answer = AskService.plainAnswer(
            for: "How is my plan?",
            engine: engine,
            formatting: formatting
        )
        XCTAssertTrue(answer.contains("₹1,00,000") || answer.contains("1,00,000"))
        XCTAssertTrue(answer.contains("Car"))
        XCTAssertTrue(answer.contains("Emergency"))
    }

    func testInflationChipAnswer() {
        let answer = AskService.plainAnswer(
            for: "Why is inflation 5%?",
            engine: AskEngineContext(),
            formatting: formatting
        )
        XCTAssertTrue(answer.contains("5%"))
    }

    func testSplitChipAnswerUsesShares() {
        let answer = AskService.plainAnswer(
            for: "What happens if I change the split?",
            engine: AskEngineContext(goals: sampleGoals(), totalSavingsPaisa: 10_000_000),
            formatting: formatting
        )
        XCTAssertTrue(answer.contains("60%") || answer.contains("60"))
        XCTAssertTrue(answer.lowercased().contains("next credit") || answer.contains("Saved"))
    }

    func testInvalidFollowUpThenForm() {
        XCTAssertFalse(AskService.shouldOpenGoalFormAfterInvalid(followUpCount: 0))
        XCTAssertTrue(AskService.shouldOpenGoalFormAfterInvalid(followUpCount: 1))
        XCTAssertEqual(AskService.maxInvalidFollowUps, 1)
    }

    func testProposalSummaryForTransfer() {
        let action = ProposedAction.transfer(from: carID, to: emergencyID, amount: 500_000)
        let summary = AskService.proposalSummary(
            for: action,
            goals: sampleGoals(),
            formatting: formatting
        )
        XCTAssertTrue(summary.contains("Car"))
        XCTAssertTrue(summary.contains("Emergency"))
        XCTAssertTrue(summary.contains("5,000") || summary.contains("₹5,000"))
    }

    func testUnavailableTemplatesNonEmpty() {
        XCTAssertFalse(AskService.unavailableTemplateSentences.isEmpty)
    }

    // MARK: - Fixtures

    private func sampleGoals() -> [Goal] {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 50_000_000,
                startDate: start,
                endDate: start.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 6_000_000,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: start,
                updatedAt: start
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 20_000_000,
                startDate: start,
                endDate: start.addingTimeInterval(86_400 * 365),
                inflationRate: Decimal(string: "0.07")!,
                savedAmount: 4_000_000,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: start,
                updatedAt: start
            )
        ]
    }
}
