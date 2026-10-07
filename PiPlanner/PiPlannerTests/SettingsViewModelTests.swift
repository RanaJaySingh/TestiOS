import XCTest
#if canImport(PiPlanner)
@testable import PiPlanner
#endif

#if canImport(Combine)
import Combine

/// Xcode-host ViewModel tests (excluded from Linux `swift test`).
@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadReflectsConsentOn() async throws {
        let persistence = InMemorySettingsPersistence()
        try await persistence.saveState(makePostSetupState(consent: true))
        let viewModel = SettingsViewModel(persistence: persistence)
        await viewModel.load()

        XCTAssertTrue(viewModel.consentAutoUpdate)
        XCTAssertEqual(viewModel.linkedAccounts.count, 2)
        XCTAssertFalse(viewModel.showsUntypedGapHint)
        XCTAssertEqual(viewModel.consentSubtitle, SettingsService.consentOnSubtitle)
    }

    func testTurningOffPersistsConsentAndShowsGapHint() async throws {
        let persistence = InMemorySettingsPersistence()
        try await persistence.saveState(makePostSetupState(consent: true))
        let viewModel = SettingsViewModel(persistence: persistence)
        await viewModel.load()

        await viewModel.turnOffAutomaticBalanceUpdates()

        XCTAssertFalse(viewModel.consentAutoUpdate)
        XCTAssertTrue(viewModel.showsUntypedGapHint)
        let state = try await persistence.loadState()
        XCTAssertFalse(SettingsService.consentAutoUpdate(in: state.accounts))
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: state.accounts), .updateBalance)
    }

    func testTurningOnReopensConsentWithoutPersistingYet() async throws {
        let persistence = InMemorySettingsPersistence()
        try await persistence.saveState(makePostSetupState(consent: false))
        let viewModel = SettingsViewModel(persistence: persistence)
        await viewModel.load()

        viewModel.setAutomaticBalanceUpdates(true)
        XCTAssertTrue(viewModel.showConsentSheet)
        XCTAssertFalse(viewModel.consentAutoUpdate)

        let state = try await persistence.loadState()
        XCTAssertFalse(SettingsService.consentAutoUpdate(in: state.accounts))
    }

    func testConfirmConsentOnPersistsAndClosesSheet() async throws {
        let persistence = InMemorySettingsPersistence()
        try await persistence.saveState(makePostSetupState(consent: false))
        let viewModel = SettingsViewModel(persistence: persistence)
        await viewModel.load()
        viewModel.setAutomaticBalanceUpdates(true)

        await viewModel.confirmConsentOn()

        XCTAssertTrue(viewModel.consentAutoUpdate)
        XCTAssertFalse(viewModel.showConsentSheet)
        let state = try await persistence.loadState()
        XCTAssertTrue(SettingsService.consentAutoUpdate(in: state.accounts))
        XCTAssertEqual(SettingsService.goalsBalanceAction(for: state.accounts), .sync)
    }

    func testConfirmResetDemoClearsStateAndSignalsHost() async throws {
        let persistence = InMemorySettingsPersistence()
        try await persistence.saveState(makePostSetupState(consent: true))
        let viewModel = SettingsViewModel(persistence: persistence)
        await viewModel.load()

        viewModel.requestResetDemo()
        XCTAssertTrue(viewModel.showResetConfirmation)

        await viewModel.confirmResetDemo()

        XCTAssertTrue(viewModel.didResetDemo)
        XCTAssertFalse(viewModel.showResetConfirmation)
        let cleared = try await persistence.loadState()
        XCTAssertTrue(cleared.goals.isEmpty)
        XCTAssertTrue(cleared.history.isEmpty)
        XCTAssertEqual(AppLaunchRouter.destination(for: cleared), .welcome)
    }

    private func makePostSetupState(consent: Bool) -> PersistedAppState {
        DemoSeed.postSetupState(consentAutoUpdate: consent)
    }
}

private final class InMemorySettingsPersistence: PersistenceServicing, @unchecked Sendable {
    private var state = PersistedAppState.empty
    private let lock = NSLock()

    func loadState() async throws -> PersistedAppState {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    func saveState(_ state: PersistedAppState) async throws {
        lock.lock(); defer { lock.unlock() }
        self.state = state
    }

    func resetDemo() async throws {
        lock.lock(); defer { lock.unlock() }
        state = .empty
    }
}
#endif
