# PIP-97 Inflation point

Ticket: https://linear.app/telco-paytm/issue/PIP-97/inflation-point

## Delivered

Inflation on goals: shared Swift formulas, inflation popup on create/edit, pending-edit copy, and unit tests. Formulas live in pure Swift (`GoalInflationFormulas`) — not Grok — so PIP-98 ledger can call the same APIs.

| Type / file | Role |
|-------------|------|
| `Services/GoalInflationFormulas.swift` | Shared API: `adjustedTargetPaisa`, `requiredSavingsPaisa`, `monthsBetween`, `yearsFromMonths` |
| `Services/GoalValidationService.swift` | Delegates inflation math to `GoalInflationFormulas` |
| `Models/Goal.swift` | `adjustedTarget` / `monthlyNeed` use shared formulas |
| `Services/GoalHeldChangeService.swift` | Toast: “Change saved. Applies at the next credit.” |
| `Views/Setup/InflationPopup.swift` | Existing PiSheet stepper (PIP-79) — create form |
| `Views/Goals/GoalEditView.swift` | DesignTokens / Pi* edit UI + inflation popup + held hint |
| `PiPlannerTests/GoalInflationFormulasTests.swift` | Exact months/12 + required-savings cases |

## Formulas

- `adjustedTarget = target × (1 + inflation) ^ (monthsStartToEnd / 12)`
- `requiredSavings = (adjustedTarget − currentSaving) / monthsRemaining` (months floored at 1; gap floored at 0)

## Mapping

| Requirement | Implementation |
|-------------|----------------|
| Inflation popup default 7% | `GoalInflationFormulas.defaultInflationRate` / `InflationPopup` |
| Edits wait for next credit | `GoalHeldChangeService` + toast / held hint |
| Formulas in Swift | `GoalInflationFormulas` (PIP-98-aligned names) |
| Create/edit UI | `GoalFormView` + `GoalEditView` + `InflationPopup` |

## Out of scope

PIP-98 ledger engine, PIP-99…108 screens, food-delivery, Android.

## Test results

`cd PiPlanner && swift test` — **223 tests, 0 failures** (includes `GoalInflationFormulasTests`).

## How to run tests

```bash
cd PiPlanner
swift test
```
