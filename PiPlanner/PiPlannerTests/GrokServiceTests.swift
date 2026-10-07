import XCTest
@testable import PiPlannerCore

final class GrokServiceTests: XCTestCase {
    private let carID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let emergencyID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

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

    /// PIP-65 — happy-path Ask copy mentions Car / Emergency Fund.
    func testAskQuestionHappyPathMentionsCarAndEmergencyFund() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "How is my car and emergency fund plan?")
        guard case .success(.plainAnswer(let text)) = result else {
            return XCTFail("Expected plain answer, got \(result)")
        }
        XCTAssertEqual(text, StubGrokService.happyPathAskAnswer)
        XCTAssertTrue(text.contains("Car"))
        XCTAssertTrue(text.contains("Emergency Fund"))
    }

    /// PIP-63 — plain answers use engine numbers when context is provided.
    func testAskQuestionPlainAnswerUsesEngineNumbers() {
        let service = StubGrokService()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let goals = [
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
            )
        ]
        let engine = AskEngineContext(goals: goals, totalSavingsPaisa: 6_000_000)
        let result = service.askQuestion(query: "How is my plan?", engine: engine)
        guard case .success(.plainAnswer(let text)) = result else {
            return XCTFail("Expected plain answer, got \(result)")
        }
        XCTAssertTrue(text.contains("Car"))
        XCTAssertTrue(text.contains("60,000") || text.contains("₹60,000"))
    }

    func testAskChipQuestionDoesNotBecomeProposal() {
        let service = StubGrokService()
        let result = service.askQuestion(
            query: "What happens if I change the split?",
            engine: AskEngineContext()
        )
        guard case .success(.plainAnswer) = result else {
            return XCTFail("Expected plain answer for chip question, got \(result)")
        }
    }

    func testAskQuestionTransferProposalWhenQueryMentionsTransfer() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "Please transfer ₹5,000")
        guard case .success(.actionProposal(let action)) = result else {
            return XCTFail("Expected action proposal, got \(result)")
        }
        XCTAssertNotNil(StubGrokService.transferPrefill(from: action))
    }

    func testAskQuestionAddGoalProposal() {
        let service = StubGrokService()
        let result = service.askQuestion(query: "Add a ₹50,000 vacation by March")
        guard case .success(.actionProposal(let action)) = result else {
            return XCTFail("Expected add-goal proposal, got \(result)")
        }
        guard case .addGoal(let proposal) = action else {
            return XCTFail("Expected addGoal action")
        }
        XCTAssertEqual(proposal.name, "Vacation")
        XCTAssertEqual(proposal.suggestedTarget, 5_000_000)
    }

    func testAskQuestionChangeSplitProposal() {
        let service = StubGrokService()
        let start = Date()
        let goals = [
            Goal(
                id: carID,
                name: "Car",
                targetAmount: 1,
                startDate: start,
                endDate: start.addingTimeInterval(86_400),
                inflationRate: 0,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.6")!,
                createdAt: start,
                updatedAt: start
            ),
            Goal(
                id: emergencyID,
                name: "Emergency Fund",
                targetAmount: 1,
                startDate: start,
                endDate: start.addingTimeInterval(86_400),
                inflationRate: 0,
                savedAmount: 0,
                shareOfNewCredits: Decimal(string: "0.4")!,
                createdAt: start,
                updatedAt: start
            )
        ]
        let result = service.askQuestion(
            query: "Change the standing split",
            engine: AskEngineContext(goals: goals, totalSavingsPaisa: 0)
        )
        guard case .success(.actionProposal(let action)) = result else {
            return XCTFail("Expected changeSplit proposal, got \(result)")
        }
        guard case .changeSplit(let splits) = action else {
            return XCTFail("Expected changeSplit action")
        }
        XCTAssertEqual(splits.count, 2)
    }

    func testAskQuestionInvalidDraftNeverReturnsProposal() {
        let service = StubGrokService()
        for query in ["", "asdf", "???", "invalid draft please"] {
            let result = service.askQuestion(query: query)
            guard case .failure(let error) = result else {
                return XCTFail("Expected invalidDraft for \(query), got \(result)")
            }
            XCTAssertEqual(error, .invalidDraft)
        }
    }

    func testAskUnavailableFallbackError() {
        let service = StubGrokService(isUnavailable: true)
        let result = service.askQuestion(
            query: "Transfer ₹5,000",
            engine: AskEngineContext()
        )
        XCTAssertEqual(result, .failure(.unavailable))
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
