import SwiftUI

/// Hosts Welcome → Accounts → Consent (placeholder). Reuses AccountsView from PIP-37.
struct WelcomeFlowView: View {
    @StateObject private var welcomeViewModel = WelcomeViewModel()
    @StateObject private var accountsViewModel: AccountsViewModel
    @State private var path = NavigationPath()

    init(accountsViewModel: AccountsViewModel) {
        _accountsViewModel = StateObject(wrappedValue: accountsViewModel)
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
                        path.append(WelcomeRoute.consent)
                    }
                case .consent:
                    ConsentPlaceholderView(
                        dedicatedAccountTitle: accountsViewModel.dedicatedAccount.map {
                            AccountsService.displayTitle(for: $0)
                        }
                    )
                }
            }
        }
    }
}

/// Navigation targets from Welcome. Accounts screen is PIP-37; Consent is PIP-39.
enum WelcomeRoute: Hashable {
    case accounts
    case consent
}
