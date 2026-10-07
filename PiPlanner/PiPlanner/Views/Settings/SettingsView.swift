import SwiftUI

/// Settings — gear from Goals tab (frames 20 / 20a / 20b / 20c) — PRD R16 / R17.
/// Standing split (PIP-51); Linked accounts, consent toggle, Reset demo (PIP-61).
/// Visual parity (PIP-93): DesignTokens / PiCard / PiSheet grouping — no behaviour change.
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
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s28) {
                    linkedAccountsSection
                    automaticUpdatesSection
                    splitsSection
                    resetSection
                }
                .padding(.horizontal, DesignTokens.Space.s20)
                .padding(.vertical, DesignTokens.Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(PiColors.backgroundApp.ignoresSafeArea())
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
            .sheet(isPresented: $viewModel.showResetConfirmation) {
                resetConfirmSheet
                    .presentationDetents([.medium])
                    .accessibilityIdentifier("settings.resetConfirm")
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
            .piPlannerTheme()
        }
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }

    // MARK: - Reset confirm chrome (frame 20)

    private var resetConfirmSheet: some View {
        PiSheet(
            title: SettingsService.resetDemoTitle,
            helper: SettingsService.resetDemoMessage
        ) {
            VStack(spacing: DesignTokens.Space.s12) {
                Button {
                    Task { await viewModel.confirmResetDemo() }
                } label: {
                    Text(SettingsService.resetDemoButtonTitle)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Space.s12)
                        .foregroundStyle(Color.white)
                        .background(PiColors.destructive)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.Radius.chip,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)
                .accessibilityIdentifier("settings.resetConfirm.confirm")

                SecondaryCTA(
                    title: "Cancel",
                    style: .outline,
                    isEnabled: !viewModel.isWorking,
                    accessibilityIdentifier: "settings.resetConfirm.cancel"
                ) {
                    viewModel.showResetConfirmation = false
                }
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
    }

    // MARK: - Sections

    private var linkedAccountsSection: some View {
        settingsGroup(title: "Linked accounts") {
            if viewModel.linkedAccounts.isEmpty {
                Text("No accounts linked yet.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
                    ForEach(Array(viewModel.linkedAccounts.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Divider()
                        }
                        accountRow(account)
                    }
                }
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
            Text(viewModel.roleLabel(for: account))
                .font(PiTypography.caption())
                .foregroundStyle(PiColors.navyPrimary)
            Text(viewModel.displayTitle(for: account))
                .font(PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(viewModel.formattedBalance(for: account))
                .font(PiTypography.body())
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(viewModel.linkSubtitle(for: account))
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.account.\(account.id.uuidString)")
    }

    private var automaticUpdatesSection: some View {
        settingsGroup(title: "Automatic balance updates") {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                HStack(alignment: .center, spacing: DesignTokens.Space.s12) {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                        HStack(spacing: DesignTokens.Space.s8) {
                            Text("Automatic balance updates")
                                .font(PiTypography.body())
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            consentStateChip
                        }
                        Text(viewModel.consentSubtitle)
                            .font(PiTypography.caption())
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { viewModel.consentAutoUpdate },
                            set: { viewModel.setAutomaticBalanceUpdates($0) }
                        )
                    )
                    .labelsHidden()
                    .tint(PiColors.navyPrimary)
                    .disabled(viewModel.isWorking)
                    .accessibilityIdentifier("settings.consentToggle")
                    .accessibilityLabel("Automatic balance updates")
                    .accessibilityValue(viewModel.consentAutoUpdate ? "On" : "Off")
                }

                if viewModel.showsUntypedGapHint {
                    Text(SettingsService.untypedGapWhileOffHint)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DesignTokens.Space.s8)
                        .accessibilityIdentifier("settings.untypedGapHint")
                }
            }
        }
    }

    /// On / Off chip — frames 20 / 20a visual state (navy when On, muted when Off).
    private var consentStateChip: some View {
        Text(viewModel.consentAutoUpdate ? "On" : "Off")
            .font(PiTypography.caption())
            .fontWeight(.semibold)
            .foregroundStyle(
                viewModel.consentAutoUpdate
                    ? PiColors.chipLightBlueLabel
                    : Color.secondary
            )
            .padding(.horizontal, DesignTokens.Space.s8)
            .padding(.vertical, 4)
            .background(
                viewModel.consentAutoUpdate
                    ? PiColors.chipLightBlue
                    : Color.secondary.opacity(0.12)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private var splitsSection: some View {
        settingsGroup(title: "Splits") {
            if goals.isEmpty {
                Text("Add a goal before setting a standing split.")
                    .font(PiTypography.body())
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink(value: SettingsRoute.standingSplit) {
                    HStack(alignment: .center, spacing: DesignTokens.Space.s12) {
                        VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                            Text("Standing split")
                                .font(PiTypography.body())
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(
                                StandingSplitService.shouldPresentEditor(goalCount: goals.count)
                                    ? "Default shares for the next credit"
                                    : "One goal — 100% automatic"
                            )
                            .font(PiTypography.caption())
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.standingSplit")
            }
        }
    }

    private var resetSection: some View {
        settingsGroup(title: "Demo") {
            Button {
                viewModel.requestResetDemo()
            } label: {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                    Text(SettingsService.resetDemoButtonTitle)
                        .font(PiTypography.body())
                        .fontWeight(.semibold)
                        .foregroundStyle(PiColors.destructive)
                    Text(SettingsService.resetDemoMessage)
                        .font(PiTypography.caption())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("settings.resetDemo")
        }
    }

    /// Design-grouped section: caption header + white PiCard body.
    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text(title)
                .font(PiTypography.caption())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            PiCard(padding: DesignTokens.Space.s16) {
                content()
            }
        }
    }
}

private enum SettingsRoute: Hashable {
    case standingSplit
}

#Preview("Settings · consent On") {
    SettingsView(
        goals: [],
        standingSplits: [],
        persistence: SettingsPreviewPersistence(),
        accounts: DemoSeed.sampleAccounts.map { account in
            var copy = account
            if copy.isDedicated {
                copy.consentAutoUpdate = true
            }
            return copy
        }
    )
}

#Preview("Settings · consent Off") {
    SettingsView(
        goals: [],
        standingSplits: [],
        persistence: SettingsPreviewPersistence(),
        accounts: DemoSeed.sampleAccounts.map { account in
            var copy = account
            if copy.isDedicated {
                copy.consentAutoUpdate = false
            }
            return copy
        }
    )
}

private actor SettingsPreviewPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty
    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
