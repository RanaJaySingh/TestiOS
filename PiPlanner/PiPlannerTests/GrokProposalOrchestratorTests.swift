import XCTest
@testable import PiPlannerCore

/// PIP-108 — Grok drafts are proposals only; engine validates before confirm card.
final class GrokProposalOrchestratorTests: XCTestCase {
    private let formatting = FormattingService()
    private let carID = DemoData.carGoalID
    private let emergencyID = DemoData.emergencyGoalID

    // MARK: - Ask starters + template fallback

    func testAskStartersMatchDesignChips() {
        XCTAssertEqual(GrokProposalOrchestrator.askStarters, AskService.suggestionChips)
        XCTAssertEqual(GrokProposalOrchestrator.askStarters.count, 2)
        XCTAssertTrue(GrokProposalOrchestrator.askStarters[0].lowercased().contains("split"))
        XCTAssertTrue(GrokProposalOrchestrator.askStarters[1].lowercased().contains("inflation"))
    }

    func testUnavailableReturnsTemplateFallbackWithoutProposals() {
        let outcome = GrokProposalOrchestrator.processAsk(
            query: "Transfer ₹5,000 from Car to Emergency Fund",
            grok: StubGrokService(isUnavailable: true),
            ledger: .postSetupDemo,
            formatting: formatting
        )
        guard case .unavailable(let templates) = outcome else {
            return XCTFail("Expected unavailable, got \(outcome)")
        }
        XCTAssertEqual(templates, AskService.unavailableTemplateSentences)
        XCTAssertFalse(templates.isEmpty)
    }

    // MARK: - Engine validate before confirm card

    func testValidTransferDraftBecomesConfirmable() {
        let outcome = GrokProposalOrchestrator.processAsk(
            query: "Transfer ₹5,000 from Car to Emergency Fund",
            grok: StubGrokService(),
            ledger: .postSetupDemo,
            formatting: formatting
        )
        guard case .confirmable(let action) = outcome else {
            return XCTFail("Expected confirmable transfer, got \(outcome)")
        }
        guard case .transfer(let from, let to, let amount) = action else {
            return XCTFail("Expected transfer action")
        }
        XCTAssertEqual(from, carID)
        XCTAssertEqual(to, emergencyID)
        XCTAssertEqual(amount, 500_000)
        // Trust boundary: orchestrator does not mutate ledger / move money.
        XCTAssertEqual(
            GrokProposalOrchestrator.validate(action, goals: DemoData.postSetupState(consentAutoUpdate: true).goals),
            .success(action)
        )
    }

    func testTransferExceedingSavedIsInvalidDraftNeverConfirmable() {
        var goals = DemoData.postSetupState(consentAutoUpdate: true).goals
        goals[0].savedAmount = 100_000 // ₹1,000 — less than demo ₹5,000 transfer
        let action = ProposedAction.transfer(from: carID, to: emergencyID, amount: 500_000)
        let result = GrokProposalOrchestrator.validate(action, goals: goals)
        guard case .failure = result else {
            return XCTFail("Expected failure when amount exceeds From saved")
        }
    }

    func testTransferUnknownGoalIsInvalidDraft() {
        let action = ProposedAction.transfer(
            from: UUID(),
            to: emergencyID,
            amount: 500_000
        )
        let result = GrokProposalOrchestrator.validate(
            action,
            goals: DemoData.postSetupState(consentAutoUpdate: true).goals
        )
        guard case .failure = result else {
            return XCTFail("Expected failure for unknown From goal")
        }
    }

    func testValidAddGoalDraftBecomesConfirmable() {
        let outcome = GrokProposalOrchestrator.processAsk(
            query: "Add a vacation goal",
            grok: StubGrokService(),
            ledger: .postSetupDemo,
            formatting: formatting
        )
        guard case .confirmable(let action) = outcome else {
            return XCTFail("Expected confirmable addGoal, got \(outcome)")
        }
        guard case .addGoal(let proposal) = action else {
            return XCTFail("Expected addGoal")
        }
        XCTAssertEqual(proposal.name, "Vacation")
        XCTAssertEqual(proposal.suggestedTarget, 5_000_000)
    }

    func testAddGoalWithEmptyNameIsInvalid() {
        let action = ProposedAction.addGoal(
            proposal: GoalProposal(name: "  ", sharePercentage: Decimal(string: "0.2")!, suggestedTarget: 1_000_000)
        )
        let result = GrokProposalOrchestrator.validate(action, goals: [])
        guard case .failure = result else {
            return XCTFail("Expected failure for empty name")
        }
    }

    func testValidChangeSplitDraftBecomesConfirmable() {
        let goals = DemoData.postSetupState(consentAutoUpdate: true).goals
        let split = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.5")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.5")!)
        ]
        let action = ProposedAction.changeSplit(newSplit: split)
        let result = GrokProposalOrchestrator.validate(action, goals: goals)
        guard case .success = result else {
            return XCTFail("Expected success for 100% standing split, got \(result)")
        }
    }

    func testChangeSplitNotHundredPercentIsInvalid() {
        let goals = DemoData.postSetupState(consentAutoUpdate: true).goals
        let split = [
            StandingSplit(goalId: carID, percentage: Decimal(string: "0.3")!),
            StandingSplit(goalId: emergencyID, percentage: Decimal(string: "0.3")!)
        ]
        let result = GrokProposalOrchestrator.validate(.changeSplit(newSplit: split), goals: goals)
        guard case .failure = result else {
            return XCTFail("Expected failure when standing split ≠ 100%")
        }
    }

    func testPlainAnswerUsesEngineNumbersNotProposalCard() {
        let outcome = GrokProposalOrchestrator.processAsk(
            query: "What happens if I change the split?",
            grok: StubGrokService(),
            ledger: .postSetupDemo,
            formatting: formatting
        )
        guard case .plainAnswer(let text) = outcome else {
            return XCTFail("Expected plain answer, got \(outcome)")
        }
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("60%") || text.contains("Car") || text.lowercased().contains("split"))
    }

    func testInvalidAskDraftNeverSurfacesConfirmable() {
        let outcome = GrokProposalOrchestrator.processAsk(
            query: "invalid draft",
            grok: StubGrokService(),
            ledger: .postSetupDemo,
            formatting: formatting
        )
        guard case .invalidDraft = outcome else {
            return XCTFail("Expected invalidDraft, got \(outcome)")
        }
    }

    // MARK: - Goal proposals (chat)

    func testHappyPathGoalProposalsValidateViaEngine() {
        let result = GrokProposalOrchestrator.validateGoalProposals(StubGrokService.happyPathProposals)
        guard case .success(let proposals) = result else {
            return XCTFail("Expected success, got \(result)")
        }
        XCTAssertEqual(proposals.map(\.name), ["Car", "Emergency Fund"])
        let shares = proposals.map(\.sharePercentage)
        XCTAssertTrue(StandingSplitService.isValidHundredPercent(shares))
    }

    func testGoalProposalsNotHundredPercentRejected() {
        let bad = [
            GoalProposal(name: "Car", sharePercentage: Decimal(string: "0.5")!, suggestedTarget: 1_000_000),
            GoalProposal(name: "Trip", sharePercentage: Decimal(string: "0.2")!, suggestedTarget: 1_000_000)
        ]
        let result = GrokProposalOrchestrator.validateGoalProposals(bad)
        guard case .failure = result else {
            return XCTFail("Expected failure when shares ≠ 100%")
        }
    }

    func testGoalProposalZeroTargetRejected() {
        let bad = [
            GoalProposal(name: "Car", sharePercentage: Decimal(string: "1")!, suggestedTarget: 0)
        ]
        let result = GrokProposalOrchestrator.validateGoalProposals(bad)
        guard case .failure = result else {
            return XCTFail("Expected failure for zero target")
        }
    }

    // MARK: - Settings Reset demo seed

    func testSettingsResetDemoReturnsWelcomeSeed() {
        let seed = SettingsService.welcomeStateAfterDemoReset()
        XCTAssertEqual(seed.accounts.map(\.id), DemoData.sampleAccounts.map(\.id))
        XCTAssertTrue(seed.goals.isEmpty)
        XCTAssertTrue(seed.history.isEmpty)
        XCTAssertTrue(seed.standingSplits.isEmpty)
        XCTAssertFalse(seed.accounts.contains(where: \.isDedicated))
    }
}

private extension GrokProposalOrchestrator.LedgerSnapshot {
    static var postSetupDemo: GrokProposalOrchestrator.LedgerSnapshot {
        let state = DemoData.postSetupState(consentAutoUpdate: true)
        return GrokProposalOrchestrator.LedgerSnapshot(
            goals: state.goals,
            standingSplits: state.standingSplits,
            accounts: state.accounts
        )
    }
}
