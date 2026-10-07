import SwiftUI

/// Hosts Accounts and navigates into Consent + balance entry + Goal chat (PIP-39 / PIP-41).
/// Prefer `WelcomeFlowView` for the full setup path; this remains for Accounts-only demos.
struct AccountsFlowView: View {
    @StateObject private var viewModel: AccountsViewModel
    @StateObject private var consentViewModel: ConsentViewModel
    @StateObject private var goalChatViewModel = GoalChatViewModel()
    @State private var openingSplitViewModel: OpeningSplitViewModel?
    @State private var path = NavigationPath()

    private let persistence: any PersistenceServicing

    init(viewModel: AccountsViewModel, persistence: any PersistenceServicing) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.persistence = persistence
        _consentViewModel = StateObject(
            wrappedValue: ConsentViewModel(
                accounts: viewModel.accounts,
                persistence: persistence
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            AccountsView(viewModel: viewModel) {
                path.append(AccountsRoute.consent)
            }
            .navigationDestination(for: AccountsRoute.self) { route in
                switch route {
                case .consent:
                    ConsentSheet(
                        viewModel: consentViewModel,
                        onYesFetched: { path.append(AccountsRoute.fetchedBalance) },
                        onNo: { path.append(AccountsRoute.updateBalance) }
                    )
                    .onAppear {
                        consentViewModel.updateAccounts(viewModel.accounts)
                    }
                case .fetchedBalance:
                    FetchedBalanceView(viewModel: consentViewModel) {
                        continueToGoalChat()
                    }
                case .updateBalance:
                    UpdateBalanceSheet(
                        onManually: { path.append(AccountsRoute.manualBalance) },
                        onBalanceSync: {
                            consentViewModel.clearPIN()
                            path.append(AccountsRoute.upiPin)
                        }
                    )
                case .manualBalance:
                    ManualBalanceView(viewModel: consentViewModel) {
                        continueToGoalChat()
                    }
                case .upiPin:
                    UPIPinView(
                        viewModel: consentViewModel,
                        onSuccess: { path.append(AccountsRoute.fetchedBalance) },
                        onWrongPin: { path.append(AccountsRoute.wrongPin) },
                        onCancel: {
                            path = NavigationPath()
                            path.append(AccountsRoute.consent)
                            path.append(AccountsRoute.updateBalance)
                        },
                        onOtherApp: { path.append(AccountsRoute.otherApp) }
                    )
                case .otherApp:
                    OtherAppView {
                        path.append(AccountsRoute.manualBalance)
                    }
                case .wrongPin:
                    WrongPinView(
                        viewModel: consentViewModel,
                        onRetry: { path.append(AccountsRoute.upiPin) },
                        onManual: { path.append(AccountsRoute.manualBalance) }
                    )
                case .goalChat:
                    GoalChatView(viewModel: goalChatViewModel) {
                        continueToOpeningSplit(goals: goalChatViewModel.definedGoals)
                    }
                case .openingSplit:
                    if let openingSplitViewModel {
                        OpeningSplitView(viewModel: openingSplitViewModel) {
                            path.append(AccountsRoute.goalsTab)
                        }
                    } else {
                        ProgressView("Loading…")
                    }
                case .goalsTab:
                    MainTabView(persistence: persistence)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    private func continueToGoalChat() {
        goalChatViewModel.reset()
        path.append(AccountsRoute.goalChat)
    }

    private func continueToOpeningSplit(goals: [Goal]) {
        let balance = consentViewModel.resolvedBalance ?? DemoSeed.openingBalancePaisa
        let resolvedGoals = goals.isEmpty ? DemoSeed.sampleGoals : goals
        openingSplitViewModel = OpeningSplitViewModel(
            goals: resolvedGoals,
            openingBalance: balance,
            persistence: persistence
        )
        path.append(AccountsRoute.openingSplit)
    }
}

/// Navigation targets from Accounts through Goal chat / Opening split.
enum AccountsRoute: Hashable {
    case consent
    case fetchedBalance
    case updateBalance
    case manualBalance
    case upiPin
    case otherApp
    case wrongPin
    case goalChat
    case openingSplit
    case goalsTab
}
