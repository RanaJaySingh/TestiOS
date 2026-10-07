import SwiftUI

/// History navigation — open credit vs read-only locked detail (PIP-59).
enum HistoryRoute: Hashable {
    case detail(UUID)
}

/// History tab — frames 12 / 12a (PIP-59). Newest first; open credit → edit; locked → read-only.
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
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("History")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.emptyStateMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("history.empty")
    }

    private var entriesList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                row(for: entry)
                    .accessibilityIdentifier("history.row.\(entry.id.uuidString)")
            }
        }
        .listStyle(.plain)
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
            showsLock: viewModel.showsLockIcon(for: entry)
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
}

#Preview("Empty") {
    NavigationStack {
        HistoryTabView(
            viewModel: HistoryViewModel(
                persistence: PreviewHistoryPersistence(state: .empty)
            )
        )
    }
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
