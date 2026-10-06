import SwiftUI

/// Consent sheet — design frame 3 (PRD R3 / R4).
struct ConsentSheet: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onYesFetched: () -> Void
    var onNo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                bullets
                actions
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Couldn’t update balance",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.isWorking },
                set: { if !$0 { /* cleared on next action */ } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step 2 of 3")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Allow balance checks?")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            if let title = viewModel.dedicatedAccountTitle {
                Text("Asked for \(title), where credits arrive.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Asked for the account where credits arrive.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(ConsentService.consentBullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 10) {
                    Text("•")
                        .font(.body)
                    Text(bullet)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ConsentService.consentBullets.joined(separator: ". "))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if await viewModel.chooseConsentYes() != nil {
                        onYesFetched()
                    }
                }
            } label: {
                Group {
                    if viewModel.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Yes, update automatically")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isWorking)
            .accessibilityLabel("Yes, update automatically")
            .accessibilityHint("Fetches opening balance for the dedicated account")

            Button {
                viewModel.chooseConsentNo()
                onNo()
            } label: {
                Text("No, I’ll update it myself")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isWorking)
            .accessibilityLabel("No, I’ll update it myself")
            .accessibilityHint("Opens Update balance options")
        }
    }
}

/// Opening balance fetched — design frame 3a (Consent Yes / PIN success).
struct FetchedBalanceView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Opening balance")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Fetched from your dedicated savings account.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedResolvedBalance)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel("Balance \(viewModel.formattedResolvedBalance)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Continue")
            .accessibilityHint("Continues setup with this opening balance")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Update balance sheet (setup) — design frame 4 (Consent No).
struct UpdateBalanceSheet: View {
    var onManually: () -> Void
    var onBalanceSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Update balance")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("How do you want to set the opening balance?")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onManually()
            } label: {
                Text("Manually")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Manually")
            .accessibilityHint("Type the opening balance")

            Button {
                onBalanceSync()
            } label: {
                Text("Balance sync")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Balance sync")
            .accessibilityHint("Opens demo UPI PIN")

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Update balance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Account on another UPI app — design frame 4c (forces manual).
struct OtherAppView: View {
    var onContinueManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Account on another UPI app")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(
                "This savings account looks linked in another UPI app. Enter the balance manually to continue setup."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onContinueManual()
            } label: {
                Text("Enter balance manually")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Enter balance manually")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Another UPI app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Wrong PIN — design frames 4d / 4e (retry or manual).
struct WrongPinView: View {
    @ObservedObject var viewModel: ConsentViewModel
    var onRetry: () -> Void
    var onManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Incorrect PIN")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.errorMessage ?? "Incorrect PIN. Try again or enter the balance manually.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                viewModel.retryPIN()
                onRetry()
            } label: {
                Text("Try again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Try again")

            Button {
                viewModel.clearPIN()
                onManual()
            } label: {
                Text("Enter manually")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Enter manually")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("UPI PIN")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Consent") {
    NavigationStack {
        ConsentSheet(
            viewModel: ConsentViewModel(
                accounts: DemoSeed.sampleAccounts.map { account in
                    var copy = account
                    copy.isDedicated = account.bankName == "HDFC"
                    return copy
                },
                persistence: PreviewConsentPersistence()
            ),
            onYesFetched: {},
            onNo: {}
        )
    }
}

/// In-memory persistence for SwiftUI previews only.
private actor PreviewConsentPersistence: PersistenceServicing {
    private var state = PersistedAppState.empty

    func loadState() async throws -> PersistedAppState { state }
    func saveState(_ state: PersistedAppState) async throws { self.state = state }
    func resetDemo() async throws { state = .empty }
}
