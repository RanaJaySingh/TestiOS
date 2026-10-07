import SwiftUI

/// Hosts Accounts and navigates into Consent sheet + balance entry + Goal chat (PIP-39 / PIP-99).
/// Prefer `WelcomeFlowView` for the full setup path; this remains for Accounts-only demos.
struct AccountsFlowView: View {
    @StateObject private var viewModel: AccountsViewModel
    @StateObject private var consentViewModel: ConsentViewModel
    @StateObject private var goalChatViewModel = GoalChatViewModel()
    @State private var openingSplitViewModel: OpeningSplitViewModel?
    @State private var path = NavigationPath()
    @State private var showConsentSheet = false

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
                consentViewModel.updateAccounts(viewModel.accounts)
                showConsentSheet = true
            }
            .sheet(isPresented: $showConsentSheet) {
                consentSheet
            }
            .navigationDestination(for: AccountsRoute.self) { route in
                switch route {
                case .fetchedBalance:
                    FetchedBalanceView(viewModel: consentViewModel) {
                        continueToGoalChat()
                    }
                case .updateBalance:
                    UpdateBalanceSheet(
                        onManually: { path.append(AccountsRoute.manualBalance) },
                        onBalanceSync: {
                            // Tip PIP-100: Paytm-linked → UPI PIN mock; Other UPI app → Manual only.
                            switch consentViewModel.route(after: .balanceSync) {
                            case .upiPinMock:
                                consentViewModel.clearPIN()
                                path.append(AccountsRoute.upiPin)
                            case .otherUPIApp:
                                path.append(AccountsRoute.otherApp)
                            default:
                                path.append(AccountsRoute.manualBalance)
                            }
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

    private var consentSheet: some View {
        NavigationStack {
            ConsentSheet(
                viewModel: consentViewModel,
                onYesFetched: {
                    showConsentSheet = false
                    path.append(AccountsRoute.fetchedBalance)
                },
                onNo: {
                    showConsentSheet = false
                    path.append(AccountsRoute.updateBalance)
                }
            )
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("setup.consentSheet")
    }

    private func continueToGoalChat() {
        goalChatViewModel.reset()
        path.append(AccountsRoute.goalChat)
    }

    private func continueToOpeningSplit(goals: [Goal]) {
        let balance = consentViewModel.resolvedBalance ?? DemoSeed.openingBalancePaisa
        var resolvedGoals = goals.isEmpty ? DemoSeed.sampleGoals : goals
        // One goal → 100% default before Opening lock / skip (PIP-101).
        if resolvedGoals.count == 1 {
            resolvedGoals[0].shareOfNewCredits = 1
        }
        // Manual / Other→Manual → typed; PIN / Consent Yes fetch → not typed (PIP-100).
        let isTyped = consentViewModel.resolvedIsTyped
            ?? UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .manualAmount)
        openingSplitViewModel = OpeningSplitViewModel(
            goals: resolvedGoals,
            openingBalance: balance,
            openingBalanceIsTyped: isTyped,
            persistence: persistence
        )
        // Single-goal still routes here; OpeningSplitView skips the editor and auto-locks.
        path.append(AccountsRoute.openingSplit)
    }
}

/// Navigation targets from Accounts through Goal chat / Opening split.
/// Consent is a sheet over Accounts — not a path destination (PIP-99).
enum AccountsRoute: Hashable {
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
