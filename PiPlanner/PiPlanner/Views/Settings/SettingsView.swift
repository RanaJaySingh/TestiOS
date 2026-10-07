import SwiftUI

/// Settings — gear from Goals tab (frames 20 / 20a / 20b / 20c) — PRD R17.
/// Standing split (PIP-51); Linked accounts, consent toggle, Reset demo (PIP-61).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let goals: [Goal]
    let standingSplits: [StandingSplit]
    let persistence: any PersistenceServicing
    /// Called after Reset demo so the app root can show Welcome (1).
    var onDemoReset: (() -> Void)?

    @StateObject private var viewModel: SettingsViewModel
    @StateObject private var consentViewModel: ConsentViewModel
    @State private var path = NavigationPath()

    init(
        goals: [Goal],
        standingSplits: [StandingSplit],
        persistence: any PersistenceServicing,
        accounts: [Account] = [],
        onDemoReset: (() -> Void)? = nil
    ) {
        self.goals = goals
        self.standingSplits = standingSplits
        self.persistence = persistence
        self.onDemoReset = onDemoReset
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                persistence: persistence,
                initialAccounts: accounts
            )
        )
        _consentViewModel = StateObject(
            wrappedValue: ConsentViewModel(
                accounts: accounts,
                persistence: persistence
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                linkedAccountsSection
                automaticUpdatesSection
                splitsSection
                resetSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .standingSplit:
                    StandingSplitView(
                        viewModel: StandingSplitViewModel(
                            goals: goals,
                            persistence: persistence,
                            standingSplits: standingSplits
                        ),
                        onDismiss: {
                            if !path.isEmpty {
                                path.removeLast()
                            }
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.load()
                consentViewModel.updateAccounts(viewModel.accounts)
            }
            .onChange(of: viewModel.didResetDemo) { didReset in
                if didReset {
                    onDemoReset?()
                    dismiss()
                }
            }
            .onChange(of: viewModel.showConsentSheet) { isPresented in
                if isPresented {
                    consentViewModel.updateAccounts(viewModel.accounts)
                }
            }
            .sheet(isPresented: $viewModel.showConsentSheet, onDismiss: {
                viewModel.consentSheetDismissed()
                Task { await viewModel.load() }
            }) {
                NavigationStack {
                    ConsentSheet(
                        viewModel: consentViewModel,
                        showsSetupStep: false,
                        fetchesBalanceOnYes: false,
                        onYesFetched: {
                            Task { await viewModel.confirmConsentOn() }
                        },
                        onNo: {
                            Task { await viewModel.declineConsentFromSheet() }
                        }
                    )
                }
                .presentationDetents([.medium, .large])
                .accessibilityIdentifier("settings.consentSheet")
            }
            .alert(
                SettingsService.resetDemoTitle,
                isPresented: $viewModel.showResetConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button(SettingsService.resetDemoButtonTitle, role: .destructive) {
                    Task { await viewModel.confirmResetDemo() }
                }
            } message: {
                Text(SettingsService.resetDemoMessage)
            }
            .alert(
                "Something went wrong",
                isPresented: showErrorAlert
            ) {
                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .accessibilityIdentifier("settings.view")
        }
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }

    // MARK: - Sections

    private var linkedAccountsSection: some View {
        Section("Linked accounts") {
            if viewModel.linkedAccounts.isEmpty {
                Text("No accounts linked yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.linkedAccounts) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.roleLabel(for: account))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.displayTitle(for: account))
                            .font(.body)
                        Text(viewModel.formattedBalance(for: account))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(viewModel.linkSubtitle(for: account))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.account.\(account.id.uuidString)")
                }
            }
        }
    }

    private var automaticUpdatesSection: some View {
        Section {
            Toggle(
                isOn: Binding(
                    get: { viewModel.consentAutoUpdate },
                    set: { viewModel.setAutomaticBalanceUpdates($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic balance updates")
                        .font(.body)
                    Text(viewModel.consentSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("settings.consentToggle")
            .accessibilityLabel("Automatic balance updates")
            .accessibilityValue(viewModel.consentAutoUpdate ? "On" : "Off")

            if viewModel.showsUntypedGapHint {
                Text(SettingsService.untypedGapWhileOffHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.untypedGapHint")
            }
        } header: {
            Text("Balance")
        }
    }

    private var splitsSection: some View {
        Section("Splits") {
            if goals.isEmpty {
                Text("Add a goal before setting a standing split.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink(value: SettingsRoute.standingSplit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Standing split")
                            .font(.body)
                        Text(
                            StandingSplitService.shouldPresentEditor(goalCount: goals.count)
                                ? "Default shares for the next credit"
                                : "One goal — 100% automatic"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.standingSplit")
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.requestResetDemo()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SettingsService.resetDemoButtonTitle)
                        .font(.body)
                    Text(SettingsService.resetDemoMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("settings.resetDemo")
        }
    }
}

private enum SettingsRoute: Hashable {
    case standingSplit
}

#Preview {
    SettingsView(
        goals: [],
        standingSplits: [],
        persistence: SettingsPreviewPersistence(),
        accounts: DemoSeed.sampleAccounts
    )
}

private actor SettingsPreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
