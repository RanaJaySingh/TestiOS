import SwiftUI

/// Hosts Opening split and navigates to Goals tab (9) after a confirmed lock.
struct OpeningSplitFlowView: View {
    @StateObject private var viewModel: OpeningSplitViewModel
    @State private var path = NavigationPath()

    init(viewModel: OpeningSplitViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $path) {
            OpeningSplitView(viewModel: viewModel) {
                path.append(OpeningSplitRoute.goalsTab)
            }
            .navigationDestination(for: OpeningSplitRoute.self) { route in
                switch route {
                case .goalsTab:
                    GoalsTabPlaceholderView()
                }
            }
        }
    }
}

/// Navigation targets from Opening split. Goals tab is the post-lock landing (PRD R6).
enum OpeningSplitRoute: Hashable {
    case goalsTab
}
