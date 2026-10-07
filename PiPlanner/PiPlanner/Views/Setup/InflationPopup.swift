import SwiftUI

/// Inflation rate popup — design frame 7. Default 7% with live adjusted target.
/// Visual parity (PIP-79): PiSheet chrome, stepper, live targets, “Use this rate” CTA.
struct InflationPopup: View {
    @Binding var inflationRate: Decimal
    let targetPaisa: Paisa
    let startDate: Date
    let endDate: Date
    var formatting: any FormattingServicing = FormattingService()
    var onDone: () -> Void

    private var percentValue: Int {
        Int(((inflationRate as NSDecimalNumber).doubleValue * 100).rounded())
    }

    private var adjustedPaisa: Paisa {
        GoalValidationService.adjustedTargetPaisa(
            targetPaisa: targetPaisa,
            inflationRate: inflationRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    var body: some View {
        PiSheet(
            title: "Inflation",
            helper: "Used to estimate an inflation-adjusted target. Default is 7%."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                stepperRow
                liveTargets
                Spacer(minLength: 0)
                PrimaryCTA(title: "Use this rate", action: onDone)
                    .accessibilityLabel("Use this rate")
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
        .presentationDetents([.medium, .large])
        .piPlannerTheme()
    }

    private var stepperRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("Rate")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Space.s16) {
                LightBlueChip(title: "−", isSelected: false) {
                    adjustPercent(by: -1)
                }
                .accessibilityLabel("Decrease inflation")

                Text("\(percentValue)%")
                    .font(PiTypography.amountHero())
                    .monospacedDigit()
                    .foregroundStyle(PiColors.navyPrimary)
                    .frame(minWidth: 72)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Inflation \(percentValue) percent")

                LightBlueChip(title: "+", isSelected: false) {
                    adjustPercent(by: 1)
                }
                .accessibilityLabel("Increase inflation")

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("inflation.stepper")
        }
    }

    private var liveTargets: some View {
        PiCard(padding: DesignTokens.Space.s16) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                Text("Adjusted target")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                Text(formatting.formatINR(paisa: adjustedPaisa))
                    .font(PiTypography.amountHero())
                    .monospacedDigit()
                    .foregroundStyle(PiColors.navyPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel(
                        "Adjusted target \(formatting.formatINR(paisa: adjustedPaisa))"
                    )
                Text("Updates live as you change the rate.")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func adjustPercent(by delta: Int) {
        let next = min(max(percentValue + delta, 0), 30)
        inflationRate = Decimal(next) / 100
    }
}

#Preview {
    InflationPopup(
        inflationRate: .constant(GoalValidationService.defaultInflationRate),
        targetPaisa: 50_000_000,
        startDate: Date(),
        endDate: Date().addingTimeInterval(86_400 * 365),
        onDone: {}
    )
}
