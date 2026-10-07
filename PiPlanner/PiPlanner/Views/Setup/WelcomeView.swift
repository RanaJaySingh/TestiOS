import SwiftUI

/// Welcome screen — design frame 1; Spec §4.2 J1 / PRD R6.
/// Visual / layout / token / component wiring only (PIP-73).
struct WelcomeView: View {
    @ObservedObject var viewModel: WelcomeViewModel
    var onNavigateToAccounts: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s28) {
                brandHeader
                howItWorksSection
                setUpButton
            }
            .padding(DesignTokens.Space.s20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .piPlannerTheme()
        .onChange(of: viewModel.shouldNavigateToAccounts) { shouldNavigate in
            if shouldNavigate {
                onNavigateToAccounts()
            }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text(viewModel.brandName)
                .font(PiTypography.amountHero())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.brand")

            Text(viewModel.tagline)
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyDeep)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.subtitle)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(viewModel.brandName). \(viewModel.tagline) \(viewModel.subtitle)"
        )
        .accessibilityIdentifier("welcome.header")
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s16) {
            Text(viewModel.howItWorksTitle)
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.howItWorks")

            PiCard(padding: DesignTokens.Space.s20) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                    ForEach(viewModel.steps) { step in
                        stepRow(step)
                    }
                }
            }
        }
        .accessibilityIdentifier("welcome.steps")
    }

    private func stepRow(_ step: WelcomeStep) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.s12) {
            Text("\(step.id)")
                .font(PiTypography.body())
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(PiColors.navyPrimary)
                .frame(width: 32, height: 32)
                .background(PiColors.chipLightBlue)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text(step.title)
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(PiColors.navyDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.detail)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.id). \(step.title). \(step.detail)")
        .accessibilityIdentifier("welcome.step.\(step.id)")
    }

    private var setUpButton: some View {
        PrimaryCTA(
            title: viewModel.ctaTitle,
            isEnabled: true,
            accessibilityIdentifier: "welcome.cta"
        ) {
            viewModel.setUpSavings()
        }
        .accessibilityLabel(viewModel.ctaTitle)
        .accessibilityHint("Continues to Accounts")
    }
}

#Preview("Welcome · first launch") {
    NavigationStack {
        WelcomeView(
            viewModel: WelcomeViewModel(),
            onNavigateToAccounts: {}
        )
    }
}

#Preview("Welcome · after Reset demo") {
    // Same visual state as first-run: empty demo → Welcome (1).
    NavigationStack {
        WelcomeView(
            viewModel: WelcomeViewModel(),
            onNavigateToAccounts: {}
        )
    }
}
