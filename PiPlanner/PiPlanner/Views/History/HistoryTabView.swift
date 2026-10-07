import SwiftUI

/// History navigation — open credit vs read-only locked detail (PIP-59 / PIP-104).
enum HistoryRoute: Hashable {
    case detail(UUID)
}

/// History tab — frames 12 / 12a (PIP-59 / PIP-104).
/// Newest first; open Assign-now credit → edit; saved/locked → read-only detail.
struct HistoryTabView: View {
    @StateObject private var viewModel: HistoryViewModel

    init(persistence: any PersistenceServicing) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(persistence: persistence))
    }

    /// Preview / tests with an injected view model.
    init(viewModel: HistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.isEmpty {
                ProgressView("Loading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HistoryRoute.self) { route in
            switch route {
            case .detail(let entryID):
                detailDestination(entryID: entryID)
            }
        }
        .sheet(isPresented: $viewModel.showCreditEntry, onDismiss: {
            viewModel.creditEntryFinished()
        }) {
            NavigationStack {
                if let entry = viewModel.activeCreditEntry {
                    CreditEntryView(
                        viewModel: CreditEntryViewModel(
                            entry: entry,
                            goals: viewModel.goals,
                            persistence: viewModel.persistence,
                            formatting: viewModel.formatting
                        )
                    ) {
                        viewModel.showCreditEntry = false
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onAppear {
            Task { await viewModel.load() }
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
        .accessibilityIdentifier("history.tab")
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Space.s16) {
            Image(systemName: PiIcons.historyTab)
                .font(.system(size: DesignTokens.TypeSize.amountHero, weight: .regular))
                .foregroundStyle(PiColors.navyPrimary.opacity(0.55))
                .frame(width: 72, height: 72)
                .background(
                    Circle()
                        .fill(PiColors.chipLightBlue.opacity(0.85))
                )
                .accessibilityHidden(true)
            Text("History")
                .font(PiTypography.title())
                .foregroundStyle(Color.primary)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.emptyStateMessage)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Space.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("history.empty")
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                row(for: entry)
                    .listRowInsets(
                        EdgeInsets(
                            top: DesignTokens.Space.s8,
                            leading: DesignTokens.Space.s16,
                            bottom: DesignTokens.Space.s8,
                            trailing: DesignTokens.Space.s16
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("history.row.\(entry.id.uuidString)")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("history.list")
    }

    @ViewBuilder
    private func row(for entry: HistoryEntry) -> some View {
        let label = HistoryEntryRow(
            typeLabel: viewModel.typeLabel(for: entry),
            systemImageName: viewModel.systemImageName(for: entry),
            subtitle: viewModel.rowSubtitle(for: entry),
            dateLabel: viewModel.dateLabel(for: entry),
            amountLabel: viewModel.amountLabel(for: entry),
            showsLock: viewModel.showsLockIcon(for: entry),
            badgeTitles: viewModel.rowBadgeTitles(for: entry)
        )
        switch viewModel.destination(for: entry) {
        case .editableCredit:
            Button {
                viewModel.presentCreditEntry(entry)
            } label: {
                label
            }
            .buttonStyle(.plain)
        case .readOnlyDetail:
            NavigationLink(value: HistoryRoute.detail(entry.id)) {
                label
            }
        }
    }

    @ViewBuilder
    private func detailDestination(entryID: UUID) -> some View {
        if let entry = viewModel.entry(id: entryID) {
            HistoryDetailView(
                entry: entry,
                goals: viewModel.goals,
                formatting: viewModel.formatting
            )
        } else {
            Text("Entry not found")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("With entries") {
    NavigationStack {
        HistoryTabView(
            viewModel: HistoryViewModel(
                persistence: PreviewHistoryPersistence(
                    state: DemoSeed.postSetupState(consentAutoUpdate: true)
                )
            )
        )
    }
    .piPlannerTheme()
}

#Preview("Empty") {
    NavigationStack {
        HistoryTabView(
            viewModel: HistoryViewModel(
                persistence: PreviewHistoryPersistence(state: .empty)
            )
        )
    }
    .piPlannerTheme()
}

/// In-memory persistence for History SwiftUI previews.
private final class PreviewHistoryPersistence: PersistenceServicing, @unchecked Sendable {
    private var state: PersistedAppState

    init(state: PersistedAppState) {
        self.state = state
    }

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
