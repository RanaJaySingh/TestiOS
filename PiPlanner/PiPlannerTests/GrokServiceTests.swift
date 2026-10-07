import XCTest
@testable import PiPlannerCore

final class GrokServiceTests: XCTestCase {
    func testHappyPathProposalCarAndEmergencyFund() {
        let service = StubGrokService()
        let result = service.analyzeGoalInput("I want a car and an emergency fund")
        guard case .success(.proposals(let proposals)) = result else {
            return XCTFail("Expected proposals, got \(result)")
        }
        XCTAssertEqual(proposals.count, 2)
        XCTAssertEqual(proposals[0].name, "Car")
        XCTAssertEqual(proposals[0].sharePercentage, Decimal(string: "0.6")!)
        XCTAssertEqual(proposals[0].suggestedTarget, 50_000_000)
        XCTAssertEqual(proposals[1].name, "Emergency Fund")
        XCTAssertEqual(proposals[1].sharePercentage, Decimal(string: "0.4")!)
        XCTAssertEqual(proposals[1].suggestedTarget, 20_000_000)

        let shares = proposals.map(\.sharePercentage)
        XCTAssertTrue(OpeningSplitService.isValidHundredPercent(shares))
    }

    func testAnalyzeGoalsSpecWrapperMatchesHappyPath() {
        let service = StubGrokService()
        let result = service.analyzeGoals(input: "Save for a car")
        guard case .success(let proposals) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(proposals.map(\.name), ["Car", "Emergency Fund"])
    }

    func testVagueInputNeedsClarification() {
        let service = StubGrokService()
        let result = service.analyzeGoalInput("save money")
        guard case .success(.needsClarification(let question)) = result else {
            return XCTFail("Expected clarification, got \(result)")
        }
        XCTAssertFalse(question.isEmpty)
        XCTAssertTrue(StubGrokService.isVague("save money"))
        XCTAssertFalse(StubGrokService.isVague("car"))
    }

    func testVagueAnalyzeGoalsMapsToInvalidDraft() {
        let service = StubGrokService()
        let result = service.analyzeGoals(input: "goals")
        guard case .failure(let error) = result else {
            return XCTFail("Expected failure for vague input")
        }
        XCTAssertEqual(error, .invalidDraft)
    }

    func testUnavailableMode() {
        let service = StubGrokService(isUnavailable: true)
        let analyze = service.analyzeGoalInput("car emergency")
        guard case .failure(let error) = analyze else {
            return XCTFail("Expected unavailable")
        }
        XCTAssertEqual(error, .unavailable)

        let ask = service.askQuestion(query: "How am I doing?")
        guard case .failure(let askError) = ask else {
            return XCTFail("Expected unavailable on ask")
        }
        XCTAssertEqual(askError, .unavailable)
    }

    func testAskQuestionPlainAnswerWhenAvailable() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "What is my plan?")
        guard case .success(.plainAnswer(let text)) = result else {
            return XCTFail("Expected plain answer, got \(result)")
        }
        XCTAssertFalse(text.isEmpty)
    }

    func testAskQuestionTransferProposalWhenQueryMentionsTransfer() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "Please transfer ₹5,000")
        guard case .success(.actionProposal(let action)) = result else {
            return XCTFail("Expected action proposal, got \(result)")
        }
        XCTAssertNotNil(StubGrokService.transferPrefill(from: action))
    }

    func testCheckedByLabelMatchesDesignCopy() {
        XCTAssertEqual(StubGrokService.checkedByLabel, "Checked by PiPlanner. Estimate.")
    }

    func testFollowUpQuestionsBounded() {
        XCTAssertEqual(StubGrokService.followUpQuestions.count, 2)
        XCTAssertEqual(
            StubGrokService.followUpQuestion(at: 0),
            StubGrokService.followUpQuestions[0]
        )
        XCTAssertEqual(
            StubGrokService.followUpQuestion(at: 1),
            StubGrokService.followUpQuestions[1]
        )
    }
}
