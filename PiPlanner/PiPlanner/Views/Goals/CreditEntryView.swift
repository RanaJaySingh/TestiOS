import SwiftUI

/// Open / locked New credit History entry (frames 13 / 13a–13g / 13t).
struct CreditEntryView: View {
    @ObservedObject var viewModel: CreditEntryViewModel
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                amountCard
                goalsSection
                if !viewModel.isLocked && !viewModel.isSingleGoal {
                    standingCheckbox
                }
                statusFooter
                if !viewModel.isLocked {
                    saveButton
                } else {
                    Button("Done", action: onDone)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("creditEntry.done")
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.isLocked ? "Credit locked" : "New credit")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Couldn’t save",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.isLocked ? "Saved credit" : "Assign this credit")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                if viewModel.isTyped {
                    Text("Typed")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .accessibilityIdentifier("creditEntry.typedBadge")
                }
            }
            Text(
                viewModel.isLocked
                    ? OpeningSplitService.lockedAmountsCaption
                    : CreditEntryService.lockedOnceCaption
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.isTyped, let previous = viewModel.formattedPrevious {
                labeledRow("Previous", previous)
            }
            if !viewModel.isTyped, let now = viewModel.formattedNewBalance {
                labeledRow("Balance now", now)
            }
            labeledRow("New amount", viewModel.formattedCreditAmount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Already saved (unchanged)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(viewModel.goals) { goal in
                goalRow(goal)
            }
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                Text(viewModel.formattedSavedSoFar(for: goal))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack {
                Text("This credit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedAmount(for: goal.id))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if viewModel.isSingleGoal {
                Text("100%")
                    .font(.title3)
                    .fontWeight(.medium)
                    .accessibilityLabel("\(goal.name) automatically assigned 100 percent")
            } else if viewModel.isLocked {
                Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                    .font(.title3)
                    .fontWeight(.medium)
            } else {
                HStack {
                    Text("\(viewModel.displayPercents[goal.id] ?? 0)%")
                        .font(.title3)
                        .fontWeight(.medium)
                        .frame(width: 56, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.displayPercents[goal.id] ?? 0) },
                            set: { viewModel.setDisplayPercent(goalID: goal.id, percent: Int($0.rounded())) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .accessibilityLabel("\(goal.name) percent")
                    .accessibilityIdentifier("creditEntry.percent.\(goal.id.uuidString)")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var standingCheckbox: some View {
        Toggle(isOn: $viewModel.useThisSplitForStanding) {
            Text(CreditEntryService.useThisSplitCheckboxTitle)
                .font(.body)
        }
        .accessibilityIdentifier("creditEntry.useStanding")
    }

    private var statusFooter: some View {
        Text(viewModel.statusMessage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("creditEntry.status")
    }

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveAndLock()
                if viewModel.isLocked {
                    onDone()
                }
            }
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Save and lock")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSave)
        .accessibilityIdentifier("creditEntry.save")
    }
}
