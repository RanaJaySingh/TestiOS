import XCTest
@testable import PiPlanner

@MainActor
final class GoalChatViewModelTests: XCTestCase {
    func testClearInputProducesProposalPhase() {
        let viewModel = GoalChatViewModel(grok: StubGrokService())
        viewModel.draftInput = "I need a car and emergency fund"
        viewModel.sendDraft()
        XCTAssertEqual(viewModel.phase, .proposal)
        XCTAssertEqual(viewModel.proposals.count, 2)
        XCTAssertEqual(viewModel.checkedByLabel, "Checked by PiPlanner. Estimate.")
    }

    func testVagueInputFollowUpsThenForm() {
        let viewModel = GoalChatViewModel(grok: StubGrokService())
        viewModel.draftInput = "save money"
        viewModel.sendDraft()
        XCTAssertEqual(viewModel.phase, .followUp)
        XCTAssertEqual(viewModel.followUpCount, 1)

        viewModel.draftInput = "goals please"
        viewModel.sendDraft()
        XCTAssertEqual(viewModel.phase, .followUp)
        XCTAssertEqual(viewModel.followUpCount, 2)

        viewModel.draftInput = "something"
        viewModel.sendDraft()
        XCTAssertEqual(viewModel.phase, .form)
    }

    func testUnavailableOffersFormPath() {
        let viewModel = GoalChatViewModel(grok: StubGrokService(isUnavailable: true))
        XCTAssertEqual(viewModel.phase, .unavailable)
        viewModel.useFormPath()
        XCTAssertEqual(viewModel.phase, .form)
    }

    func testConfirmProposalsEnablesContinueAtHundredPercent() {
        let viewModel = GoalChatViewModel(grok: StubGrokService())
        viewModel.draftInput = "car"
        viewModel.sendDraft()
        viewModel.confirmProposals()
        XCTAssertEqual(viewModel.phase, .goalsDefined)
        XCTAssertTrue(viewModel.canContinue)
        viewModel.updateShare(for: viewModel.definedGoals[0].id, displayPercent: 50)
        XCTAssertFalse(viewModel.canContinue)
    }

    func testFormSaveDisabledUntilValid() {
        let viewModel = GoalChatViewModel()
        viewModel.useFormPath()
        XCTAssertFalse(viewModel.formDraft.canSave)
        viewModel.formDraft.name = "Trip"
        viewModel.formDraft.targetRupeeDigits = "50000"
        XCTAssertTrue(viewModel.formDraft.canSave)
        XCTAssertTrue(viewModel.saveForm())
        XCTAssertEqual(viewModel.phase, .goalsDefined)
        XCTAssertEqual(viewModel.definedGoals.first?.name, "Trip")
    }
}
