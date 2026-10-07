import SwiftUI

/// Hosts Welcome → Accounts → Consent sheet → balance → Goal chat → Opening split (PIP-99).
struct WelcomeFlowView: View {
    @StateObject private var welcomeViewModel = WelcomeViewModel()
    @StateObject private var accountsViewModel: AccountsViewModel
    @StateObject private var consentViewModel: ConsentViewModel
    @StateObject private var goalChatViewModel = GoalChatViewModel()
    @State private var openingSplitViewModel: OpeningSplitViewModel?
    @State private var path = NavigationPath()
    /// Consent is a sheet over Accounts (frame 3), not a pushed destination.
    @State private var showConsentSheet = false

    private let persistence: any PersistenceServicing

    init(accountsViewModel: AccountsViewModel, persistence: any PersistenceServicing) {
        _accountsViewModel = StateObject(wrappedValue: accountsViewModel)
        self.persistence = persistence
        _consentViewModel = StateObject(
            wrappedValue: ConsentViewModel(
                accounts: accountsViewModel.accounts,
                persistence: persistence
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(viewModel: welcomeViewModel) {
                path.append(WelcomeRoute.accounts)
            }
            .navigationDestination(for: WelcomeRoute.self) { route in
                switch route {
                case .accounts:
                    AccountsView(viewModel: accountsViewModel) {
                        consentViewModel.updateAccounts(accountsViewModel.accounts)
                        showConsentSheet = true
                    }
                    .sheet(isPresented: $showConsentSheet) {
                        consentSheet
                    }
                case .fetchedBalance:
                    FetchedBalanceView(viewModel: consentViewModel) {
                        continueToGoalChat()
                    }
                case .updateBalance:
                    UpdateBalanceSheet(
                        onManually: { path.append(WelcomeRoute.manualBalance) },
                        onBalanceSync: {
                            // PIP-100: Paytm-linked → UPI PIN mock; Other UPI app → Manual only.
                            switch consentViewModel.route(after: .balanceSync) {
                            case .upiPinMock:
                                consentViewModel.clearPIN()
                                path.append(WelcomeRoute.upiPin)
                            case .otherUPIApp:
                                path.append(WelcomeRoute.otherApp)
                            default:
                                path.append(WelcomeRoute.manualBalance)
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
                        onSuccess: { path.append(WelcomeRoute.fetchedBalance) },
                        onWrongPin: { path.append(WelcomeRoute.wrongPin) },
                        onCancel: { returnToUpdateBalance() },
                        onOtherApp: { path.append(WelcomeRoute.otherApp) }
                    )
                case .otherApp:
                    OtherAppView {
                        path.append(WelcomeRoute.manualBalance)
                    }
                case .wrongPin:
                    WrongPinView(
                        viewModel: consentViewModel,
                        onRetry: { path.append(WelcomeRoute.upiPin) },
                        onManual: { path.append(WelcomeRoute.manualBalance) }
                    )
                case .goalChat:
                    GoalChatView(viewModel: goalChatViewModel) {
                        continueToOpeningSplit(goals: goalChatViewModel.definedGoals)
                    }
                case .openingSplit:
                    if let openingSplitViewModel {
                        OpeningSplitView(viewModel: openingSplitViewModel) {
                            path.append(WelcomeRoute.goalsTab)
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

    /// Paytm-like Consent sheet over Accounts (Yes → auto updates + fetch; No → Update balance).
    private var consentSheet: some View {
        NavigationStack {
            ConsentSheet(
                viewModel: consentViewModel,
                onYesFetched: {
                    showConsentSheet = false
                    path.append(WelcomeRoute.fetchedBalance)
                },
                onNo: {
                    showConsentSheet = false
                    path.append(WelcomeRoute.updateBalance)
                }
            )
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("setup.consentSheet")
    }

    private func continueToGoalChat() {
        goalChatViewModel.reset()
        path.append(WelcomeRoute.goalChat)
    }

    private func continueToOpeningSplit(goals: [Goal]) {
        let balance = consentViewModel.resolvedBalance ?? DemoSeed.openingBalancePaisa
        var resolvedGoals = goals.isEmpty ? DemoSeed.sampleGoals : goals
        // One goal → 100% default before Opening lock / skip (PIP-101).
        if resolvedGoals.count == 1 {
            resolvedGoals[0].shareOfNewCredits = 1
        }
        // Manual / Other→Manual → typed; PIN / Consent Yes fetch → not typed (PIP-100 History shape).
        let isTyped = consentViewModel.resolvedIsTyped
            ?? UpdateBalanceRoutingService.isTypedBalance(resolvedFrom: .manualAmount)
        openingSplitViewModel = OpeningSplitViewModel(
            goals: resolvedGoals,
            openingBalance: balance,
            openingBalanceIsTyped: isTyped,
            persistence: persistence
        )
        // Single-goal still routes here; OpeningSplitView skips the editor and auto-locks.
        path.append(WelcomeRoute.openingSplit)
    }

    /// Cancel / leave PIN returns to Update balance (4) with a stable stack.
    private func returnToUpdateBalance() {
        path = NavigationPath()
        path.append(WelcomeRoute.accounts)
        path.append(WelcomeRoute.updateBalance)
    }
}

/// Navigation targets from Welcome through Goal chat / Opening split (PIP-35 / 37 / 39 / 41 / 99).
/// Consent is presented as a sheet from Accounts — not a path destination.
enum WelcomeRoute: Hashable {
    case accounts
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
