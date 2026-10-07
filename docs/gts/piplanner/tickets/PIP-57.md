# PIP-57 [iOS] Implement Withdrawal flow

Ticket: https://linear.app/telco-paytm/issue/PIP-57/ios-implement-withdrawal-flow

## Delivered

Withdrawal flow under `PiPlanner/Views/Goals/WithdrawalView.swift` (+ `WithdrawalFlow` / `RecordWithdrawalSheet`), `WithdrawalViewModel`, pure `WithdrawalService`, locked History `withdrawal` entry, proportional default by current savings, edit-once reductions, invalid-total / goal-below-zero validation. Goals tab wires Sync/Update lower-balance (10b) and manual **Record a withdrawal** (18c). Standing split unchanged.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R15 / BR-8 Withdrawal proportional; no goal below ₹0 | `WithdrawalService.proportionalReductions` + `canSave` / `goalBelowZero` |
| Total reductions = shortfall (18a) | `invalidTotalMessage` + Save disabled when total ≠ shortfall |
| Edit once then Save and lock | `WithdrawalViewModel` Edit → Done → `hasEditedOnce` |
| History withdrawal (18b) | Locked `HistoryEntryType.withdrawal` with allocations + balances |
| Manual Record a withdrawal (18c) | `RecordWithdrawalSheet` + Goals / Update balance link |
| Standing split separate | `applyWithdrawal` does not mutate `standingSplits` |
| Sync lower (10b) entry | `GoalsViewModel.handleWithdrawal` from Credit Sync/Update sheets |

## Acceptance criteria

- [x] Given lower balance detected (10b / 18c), when Withdrawal (18) opened, then proportional allocation is default
- [x] Given reductions, when edited once, then user can modify before Save
- [x] Given total reductions, when they ≠ shortfall (18a), then Save disabled with running total shown
- [x] Given any goal, when reduction would make it < ₹0, then validation prevents it
- [x] Given valid withdrawal, when Save and lock tapped, then History entry (18b) created
- [x] Given Record a withdrawal (18c), when initiated manually, then same flow opens
- [x] States: Proportional default, Edit, Invalid total, Goal below zero, Complete
- [x] Tests: Unit test for proportional calculation and validation

## Parallel work / base

Started from `main` @ `a6c318ec9d0b401d036832b18c0b1afc95e17538` (PIP-53 Delete goal merged). Additive Goals wiring only — Credit* Sync/Update sheets kept; optional `onRecordWithdrawal` on Update sheet. Transfer (PIP-55) left untouched.

## How to run tests

```bash
cd PiPlanner
swift test
```

**Result (this run):** 133 tests, 0 failures (includes 10 `WithdrawalServiceTests`).

## Assumptions

- “Editable once” = one Edit → Done pass locks reduction amounts until Save (proportional default usable without editing).
- Proportional weights use current `savedAmount` (not standing %); zero-saved goals get ₹0 reduction; all-zero saved falls back to equal.
- Manual 18c: user enters shortfall in rupees; `newBalance = previous − shortfall`.
- Design frames 18 / 18a / 18b / 18c inferred from PRD R15 + Spec BR-8 (artifact not scraped in-agent).

## Out of scope

Transfer UI (PIP-55); rewriting Credit* / Standing split / DeleteGoal; History tab polish beyond locked entry write.
