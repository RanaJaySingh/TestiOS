import Combine
import Foundation

/// One "How it works" step on Welcome (design frame 1).
struct WelcomeStep: Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let detail: String
}

/// View model for Welcome (frame 1) — PRD R1.
@MainActor
final class WelcomeViewModel: ObservableObject {
    let brandName = "PiPlanner"
    let tagline = "Every Rupee Has a Plan."
    let subtitle = "Every credit to savings gets a goal before it can be spent."
    let howItWorksTitle = "How it works"
    let ctaTitle = "Set up savings"

    let steps: [WelcomeStep] = [
        WelcomeStep(
            id: 1,
            title: "Pick a savings account",
            detail: "Only its balance is read."
        ),
        WelcomeStep(
            id: 2,
            title: "Set your goals",
            detail: "A target, an end date and a share of each credit."
        ),
        WelcomeStep(
            id: 3,
            title: "Split every new credit",
            detail: "Saved amounts lock, so they stay put."
        )
    ]

    @Published private(set) var shouldNavigateToAccounts = false

    func setUpSavings() {
        shouldNavigateToAccounts = true
    }
}
