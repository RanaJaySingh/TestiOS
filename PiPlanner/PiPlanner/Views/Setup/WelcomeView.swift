import SwiftUI

/// Welcome screen — design frame 1; Spec §4.2 / PRD R1.
struct WelcomeView: View {
    @ObservedObject var viewModel: WelcomeViewModel
    var onNavigateToAccounts: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                brandHeader
                howItWorksSection
                setUpButton
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.shouldNavigateToAccounts) { shouldNavigate in
            if shouldNavigate {
                onNavigateToAccounts()
            }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.brandName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.brand")

            Text(viewModel.tagline)
                .font(.title2)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.subtitle)
                .font(.body)
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
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.howItWorksTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.howItWorks")

            ForEach(viewModel.steps) { step in
                stepRow(step)
            }
        }
        .accessibilityIdentifier("welcome.steps")
    }

    private func stepRow(_ step: WelcomeStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(step.id)")
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(width: 28, height: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.detail)
                    .font(.subheadline)
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
        Button {
            viewModel.setUpSavings()
        } label: {
            Text(viewModel.ctaTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(viewModel.ctaTitle)
        .accessibilityHint("Continues to Accounts")
        .accessibilityIdentifier("welcome.cta")
    }
}

#Preview {
    NavigationStack {
        WelcomeView(
            viewModel: WelcomeViewModel(),
            onNavigateToAccounts: {}
        )
    }
}
