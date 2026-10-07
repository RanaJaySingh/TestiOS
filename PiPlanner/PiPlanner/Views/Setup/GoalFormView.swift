import SwiftUI

/// Goal form · create / edit — design frame 6 (PRD R5).
struct GoalFormView: View {
    @ObservedObject var viewModel: GoalChatViewModel
    var onSaved: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                nameField
                targetField
                dateFields
                inflationRow
                shareField
                savedRow
                metrics
                saveButton
                if viewModel.phase == .form {
                    Button("Cancel") {
                        viewModel.cancelForm()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showInflationPopup) {
            InflationPopup(
                inflationRate: Binding(
                    get: { viewModel.formDraft.inflationRate },
                    set: { viewModel.formDraft.inflationRate = $0 }
                ),
                targetPaisa: viewModel.formDraft.targetPaisa,
                startDate: viewModel.formDraft.startDate,
                endDate: viewModel.formDraft.endDate,
                onDone: { viewModel.showInflationPopup = false }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Define a goal")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            Text("Name, target, dates, and share of new credits. Inflation defaults to 7%.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("e.g. Car", text: $viewModel.formDraft.name)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Goal name")
        }
    }

    private var targetField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹")
                    .font(.title3)
                    .fontWeight(.semibold)
                TextField(
                    "0",
                    text: Binding(
                        get: { viewModel.formDraft.targetRupeeDigits },
                        set: { viewModel.formDraft.targetRupeeDigits = $0.filter(\.isNumber) }
                    )
                )
                .keyboardType(.numberPad)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityLabel("Target in rupees")
            }
            Text(viewModel.formatINR(paisa: viewModel.formDraft.targetPaisa))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var dateFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "Start",
                selection: $viewModel.formDraft.startDate,
                displayedComponents: .date
            )
            DatePicker(
                "End",
                selection: $viewModel.formDraft.endDate,
                displayedComponents: .date
            )
        }
    }

    private var inflationRow: some View {
        Button {
            viewModel.showInflationPopup = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inflation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.formDraft.inflationPercentDisplay)%")
                        .font(.body)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                Spacer()
                Text("Edit")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Inflation \(viewModel.formDraft.inflationPercentDisplay) percent")
        .accessibilityHint("Opens inflation popup")
    }

    private var shareField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Share of new credits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.formDraft.sharePercentDisplay)%")
                    .font(.body)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: {
                        (viewModel.formDraft.shareOfNewCredits as NSDecimalNumber).doubleValue * 100
                    },
                    set: { viewModel.formDraft.shareOfNewCredits = Decimal($0) / 100 }
                ),
                in: 0...100,
                step: 1
            )
            .accessibilityLabel("Share of new credits")
        }
    }

    private var savedRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved so far")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.formatINR(paisa: viewModel.formDraft.savedAmount))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text("Locked at ₹0 while creating a goal in setup.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricRow(
                title: "Inflation-adjusted target",
                value: viewModel.formatINR(paisa: viewModel.formDraft.adjustedTargetPaisa)
            )
            metricRow(
                title: "Monthly need",
                value: viewModel.formatINR(paisa: viewModel.formDraft.monthlyNeedPaisa)
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var saveButton: some View {
        Button {
            if viewModel.saveForm() {
                onSaved?()
            }
        } label: {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.formDraft.canSave)
        .accessibilityLabel("Save goal")
        .accessibilityHint(
            viewModel.formDraft.canSave
                ? "Saves this goal"
                : "Disabled until name, target, and dates are valid"
        )
    }
}

#Preview {
    NavigationStack {
        GoalFormView(viewModel: GoalChatViewModel())
    }
}
