import SwiftUI

/// Hosts Accounts and navigates to Consent (placeholder) after Continue.
/// Production first-run entry is `WelcomeFlowView` (PIP-35); kept for Accounts-only previews/tests.
struct AccountsFlowView: View {
    @StateObject private var viewModel: AccountsViewModel
    @State private var path = NavigationPath()

    init(viewModel: AccountsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $path) {
            AccountsView(viewModel: viewModel) {
                path.append(AccountsRoute.consent)
            }
            .navigationDestination(for: AccountsRoute.self) { route in
                switch route {
                case .consent:
                    ConsentPlaceholderView(
                        dedicatedAccountTitle: viewModel.dedicatedAccount.map {
                            AccountsService.displayTitle(for: $0)
                        }
                    )
                }
            }
        }
    }
}

/// Navigation targets from Accounts. Consent sheet is PIP-39.
enum AccountsRoute: Hashable {
    case consent
}
