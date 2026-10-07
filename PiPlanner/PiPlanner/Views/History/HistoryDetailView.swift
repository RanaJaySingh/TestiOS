import SwiftUI

/// Read-only History entry (frame 12a) — locked / Opening balance.
///
/// PIP-85: New credit locked detail uses Saved and locked + Typed/Custom badges
/// and a this-credit allocations block (visual only; no behaviour change).
struct HistoryDetailView: View {
    let entry: HistoryEntry
    let goals: [Goal]
    let formatting: any FormattingServicing

    private var typeLabel: String { HistoryService.typeLabel(for: entry) }
    private var isNewCredit: Bool { entry.type == .newCredit }
    private var isTyped: Bool { HistoryService.showsTypedBadge(entry) }
    private var showsCustomBadge: Bool { HistoryService.showsCustomSplitBadge(entry) }

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
            VStack(alignment: .leading, spacing: DesignTokens.Space.s20) {
                header
                summary
                if !entry.allocations.isEmpty {
                    allocationsSection
                }
                Text(HistoryService.originalAmountsCaption)
                    .font(PiTypography.caption())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("history.detail.originalCaption")
            }
            .padding(DesignTokens.Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PiColors.backgroundApp.ignoresSafeArea())
        .navigationTitle(typeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .piPlannerTheme()
        .accessibilityIdentifier("history.detail")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            if isNewCredit {
                newCreditLockedHeader
            } else {
                genericHeader
            }

            Text(HistoryService.originalAmountsCaption)
                .font(PiTypography.body())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var newCreditLockedHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
            Text("New credit")
                .font(PiTypography.caption())
                .foregroundStyle(PiColors.navyPrimary.opacity(0.72))
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .center, spacing: DesignTokens.Space.s8) {
                HStack(spacing: DesignTokens.Space.s8) {
                    if HistoryService.showsLockIcon(entry) {
                        Image(systemName: PiIcons.lock)
                            .font(.title3)
                            .foregroundStyle(PiColors.navyPrimary)
                            .accessibilityLabel("Locked")
                            .accessibilityIdentifier("history.detail.lockIcon")
                    }
                    Text("Saved and locked")
                        .font(PiTypography.title())
                        .foregroundStyle(PiColors.navyPrimary)
                        .accessibilityIdentifier("history.detail.savedAndLocked")
                }
                Spacer(minLength: DesignTokens.Space.s8)
                badges
            }
        }
    }

    private var genericHeader: some View {
        HStack(spacing: DesignTokens.Space.s8) {
            Image(systemName: HistoryService.systemImageName(for: entry))
                .font(.title2)
                .foregroundStyle(PiColors.navyPrimary.opacity(0.72))
            Text(typeLabel)
                .font(PiTypography.title())
                .foregroundStyle(PiColors.navyPrimary)
                .accessibilityAddTraits(.isHeader)
            if HistoryService.showsLockIcon(entry) {
                Image(systemName: PiIcons.lock)
                    .foregroundStyle(PiColors.navyPrimary)
                    .accessibilityLabel("Locked")
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        HStack(spacing: DesignTokens.Space.s8) {
            if isTyped {
                entryBadge(title: "Typed", accessibilityIdentifier: "history.detail.typedBadge")
            }
            if showsCustomBadge {
                entryBadge(title: "Custom", accessibilityIdentifier: "history.detail.customBadge")
            }
        }
    }

    private func entryBadge(title: String, accessibilityIdentifier: String) -> some View {
        Text(title)
            .font(PiTypography.caption())
            .fontWeight(.semibold)
            .foregroundStyle(PiColors.chipLightBlueLabel)
            .padding(.horizontal, DesignTokens.Space.s12)
            .padding(.vertical, DesignTokens.Space.s8)
            .background(PiColors.chipLightBlue)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous))
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var summary: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s8) {
                labeledRow("Amount", amountLabel, emphasize: true)
                // Typed credits (13t): no Previous / Balance now lines — match CreditEntryView.
                if !(isNewCredit && isTyped) {
                    if let previous = entry.previousBalance {
                        labeledRow("Previous balance", formatting.formatINR(paisa: previous))
                    }
                    if let newBalance = entry.newBalance {
                        labeledRow("Balance after", formatting.formatINR(paisa: newBalance))
                    }
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.detail.summary")
    }

    private var allocationsSection: some View {
        PiCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s12) {
                Text(isNewCredit ? thisCreditSectionTitle : "Allocations")
                    .font(PiTypography.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(isNewCredit ? PiColors.navyPrimary : .primary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(
                        isNewCredit ? "history.detail.thisCreditHeader" : "history.detail.allocationsHeader"
                    )

                ForEach(entry.allocations, id: \.goalId) { allocation in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(allocation.goalName)
                                .font(PiTypography.body())
                                .fontWeight(.medium)
                            Text("\(GoalValidationService.displayPercent(fromFraction: allocation.percentage))%")
                                .font(PiTypography.caption())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatting.formatINR(paisa: allocation.amount))
                            .font(PiTypography.body())
                            .fontWeight(.semibold)
                            .foregroundStyle(PiColors.navyPrimary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("history.detail.allocations")
    }

    private var thisCreditSectionTitle: String {
        if let amount = entry.creditAmount {
            return "Split \(formatting.formatINR(paisa: amount)) · This credit only"
        }
        return "This credit only"
    }

    private func labeledRow(_ title: String, _ value: String, emphasize: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(PiTypography.caption())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(emphasize ? PiTypography.title() : PiTypography.body())
                .fontWeight(.semibold)
                .foregroundStyle(emphasize ? PiColors.navyPrimary : .primary)
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
