import SwiftUI

/// Inflation rate popup — design frame 7. Default 5% with typed rate + live adjusted target (PIP-109).
/// Visual parity (PIP-79): PiSheet chrome, editable %, optional steppers, live targets, “Use this rate” CTA.
struct InflationPopup: View {
    @Binding var inflationRate: Decimal
    let targetPaisa: Paisa
    let startDate: Date
    let endDate: Date
    var formatting: any FormattingServicing = FormattingService()
    var onDone: () -> Void

    @State private var rateText: String = ""
    @State private var showRateError = false

    private var effectiveRate: Decimal {
        GoalInflationFormulas.effectiveInflationRate(fromPercentText: rateText)
    }

    private var adjustedPaisa: Paisa {
        GoalValidationService.adjustedTargetPaisa(
            targetPaisa: targetPaisa,
            inflationRate: effectiveRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    var body: some View {
        PiSheet(
            title: "Inflation",
            helper: "Used to estimate an inflation-adjusted target. Default is 5%."
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                rateFieldRow
                liveTargets
                Spacer(minLength: 0)
                PrimaryCTA(title: "Use this rate", action: commitAndDismiss)
                    .accessibilityLabel("Use this rate")
            }
            .padding(.horizontal, DesignTokens.Space.s20)
            .padding(.bottom, DesignTokens.Space.s28)
        }
        .presentationDetents([.medium, .large])
        .piPlannerTheme()
        .onAppear {
            rateText = "\(GoalInflationFormulas.displayPercent(fromFraction: inflationRate))"
            showRateError = false
        }
    }

    private var rateFieldRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("Rate")
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Space.s16) {
                LightBlueChip(title: "−", isSelected: false) {
                    adjustPercent(by: -1)
                }
                .accessibilityLabel("Decrease inflation")

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    TextField(
                        "\(GoalInflationFormulas.defaultInflationPercent)",
                        text: Binding(
                            get: { rateText },
                            set: { applyTypedRate($0) }
                        )
                    )
                    .keyboardType(.numberPad)
                    .font(PiTypography.amountHero())
                    .monospacedDigit()
                    .foregroundStyle(PiColors.navyPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 56)
                    .accessibilityLabel("Inflation rate percent")
                    .accessibilityIdentifier("inflation.rateField")

                    Text("%")
                        .font(PiTypography.amountHero())
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, DesignTokens.Space.s12)
                .padding(.vertical, DesignTokens.Space.s8)
                .background(PiColors.backgroundApp)
                .clipShape(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                        .strokeBorder(
                            showRateError ? PiColors.behind.opacity(0.55) : Color.clear,
                            lineWidth: showRateError ? 1.5 : 0
                        )
                )

                LightBlueChip(title: "+", isSelected: false) {
                    adjustPercent(by: 1)
                }
                .accessibilityLabel("Increase inflation")

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("inflation.rateRow")

            if showRateError {
                Text(GoalInflationFormulas.invalidInflationPercentMessage)
                    .font(PiTypography.caption())
                    .foregroundStyle(PiColors.behind)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(GoalInflationFormulas.invalidInflationPercentMessage)
                    .accessibilityIdentifier("inflation.rateError")
            }
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
                    .accessibilityIdentifier("inflation.adjustedTarget")
                Text("Updates live as you change the rate.")
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func applyTypedRate(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        rateText = digits
        if let percent = GoalInflationFormulas.parseInflationPercentText(digits) {
            inflationRate = GoalInflationFormulas.inflationRate(fromPercent: percent)
            showRateError = false
        } else {
            showRateError = true
            // Keep binding at default while invalid so form draft stays sensible.
            inflationRate = GoalInflationFormulas.defaultInflationRate
        }
    }

    private func adjustPercent(by delta: Int) {
        let current = GoalInflationFormulas.parseInflationPercentText(rateText)
            ?? GoalInflationFormulas.defaultInflationPercent
        let next = min(
            max(current + delta, GoalInflationFormulas.minInflationPercent),
            GoalInflationFormulas.maxInflationPercent
        )
        rateText = "\(next)"
        inflationRate = GoalInflationFormulas.inflationRate(fromPercent: next)
        showRateError = false
    }

    private func commitAndDismiss() {
        if let percent = GoalInflationFormulas.parseInflationPercentText(rateText) {
            inflationRate = GoalInflationFormulas.inflationRate(fromPercent: percent)
        } else {
            inflationRate = GoalInflationFormulas.defaultInflationRate
            rateText = "\(GoalInflationFormulas.defaultInflationPercent)"
            showRateError = false
        }
        onDone()
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
