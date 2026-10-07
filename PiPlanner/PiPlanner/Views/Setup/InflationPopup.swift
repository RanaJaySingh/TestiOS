import SwiftUI

/// Inflation rate popup — design frame 7. Default 7% with live adjusted target.
struct InflationPopup: View {
    @Binding var inflationRate: Decimal
    let targetPaisa: Paisa
    let startDate: Date
    let endDate: Date
    var formatting: any FormattingServicing = FormattingService()
    var onDone: () -> Void

    private var percentBinding: Binding<Double> {
        Binding(
            get: {
                (inflationRate as NSDecimalNumber).doubleValue * 100
            },
            set: { newValue in
                let clamped = min(max(newValue, 0), 30)
                inflationRate = Decimal(clamped) / 100
            }
        )
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
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Inflation")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text("Used to estimate an inflation-adjusted target. Default is 7%.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(percentBinding.wrappedValue.rounded()))%")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .accessibilityLabel("Inflation \(Int(percentBinding.wrappedValue.rounded())) percent")
                    }
                    Slider(value: percentBinding, in: 0...30, step: 1)
                        .accessibilityLabel("Inflation rate")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjusted target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatting.formatINR(paisa: adjustedPaisa))
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .accessibilityLabel(
                            "Adjusted target \(formatting.formatINR(paisa: adjustedPaisa))"
                        )
                }

                Spacer(minLength: 0)

                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Done")
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
