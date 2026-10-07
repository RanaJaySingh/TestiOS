import SwiftUI

/// Read-only History entry (frame 12a) — locked / Opening balance.
struct HistoryDetailView: View {
    let entry: HistoryEntry
    let goals: [Goal]
    let formatting: any FormattingServicing

    private var typeLabel: String { HistoryService.typeLabel(for: entry) }

    private var amountLabel: String {
        guard let amount = HistoryService.primaryAmountPaisa(for: entry) else {
            return "—"
        }
        return formatting.formatINR(paisa: amount)
    }

    private var transferSubtitle: String? {
        HistoryService.rowSubtitle(for: entry, goals: goals, formatting: formatting)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summary
                if !entry.allocations.isEmpty {
                    allocationsSection
                }
                Text(HistoryService.originalAmountsCaption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("history.detail.originalCaption")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(typeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.detail")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: HistoryService.systemImageName(for: entry))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(typeLabel)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                if HistoryService.showsLockIcon(entry) {
                    Image(systemName: PiIcons.lock)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Locked")
                }
            }
            Text(HistoryService.originalAmountsCaption)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledRow("Amount", amountLabel)
            if let previous = entry.previousBalance {
                labeledRow("Previous balance", formatting.formatINR(paisa: previous))
            }
            if let newBalance = entry.newBalance {
                labeledRow("Balance after", formatting.formatINR(paisa: newBalance))
            }
            if entry.type == .transfer, let transferSubtitle {
                labeledRow("Transfer", transferSubtitle)
            }
            if entry.type == .goalDeleted, let name = entry.deletedGoalName {
                labeledRow("Deleted goal", name)
            }
            if let released = entry.releasedAmount, entry.type == .goalDeleted {
                labeledRow("Released", formatting.formatINR(paisa: released))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.detail.summary")
    }

    private var allocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allocations")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(entry.allocations, id: \.goalId) { allocation in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(allocation.goalName)
                            .font(.body)
                            .fontWeight(.medium)
                        Text("\(GoalValidationService.displayPercent(fromFraction: allocation.percentage))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatting.formatINR(paisa: allocation.amount))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("history.detail.allocations")
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            entry: HistoryEntry(
                id: UUID(),
                type: .openingBalance,
                createdAt: Date(),
                isLocked: true,
                previousBalance: nil,
                newBalance: 10_000_000,
                creditAmount: 10_000_000,
                isTyped: false,
                fromGoalId: nil,
                toGoalId: nil,
                transferAmount: nil,
                withdrawalAmount: nil,
                deletedGoalName: nil,
                releasedAmount: nil,
                allocations: [
                    GoalAllocation(
                        goalId: DemoSeed.sampleGoals[0].id,
                        goalName: "Car",
                        amount: 6_000_000,
                        percentage: Decimal(string: "0.6")!
                    ),
                    GoalAllocation(
                        goalId: DemoSeed.sampleGoals[1].id,
                        goalName: "Emergency Fund",
                        amount: 4_000_000,
                        percentage: Decimal(string: "0.4")!
                    )
                ]
            ),
            goals: DemoSeed.sampleGoals,
            formatting: FormattingService()
        )
    }
}
