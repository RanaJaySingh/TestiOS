# PIP-98 Ledger engine + unit tests

Ticket: https://linear.app/telco-paytm/issue/PIP-98/ledger-engine-unit-tests

## Delivered

Pure Swift `LedgerEngineCore` (Linux-testable) under `PiPlanner/Services`, with focused unit tests. No new screens. Extends existing Models/Services; mutations delegate to `CreditEntryService`, `StandingSplitService`, `GoalHeldChangeService`, `TransferService`, `DeleteGoalService`, `WithdrawalService`.

| API surface | Role |
|-------------|------|
| `LedgerEngineCore.adjustedTargetPaisa` / `requiredSavingsPaisa` / `status` | Formulas via tip `GoalInflationFormulas` (PIP-97); on-track status |
| `BalanceSnapshot` + `applyBalanceDelta` | Snapshot / delta (fetched vs typed) |
| `lockedSlices` / `saveOpenCredit` / `isAppendOnlyMutation` | History open → save helpers (tip PIP-103 owns UI Save path) |
| `applyStanding` / `singleGoalStandingPercentages` | Standing split (1 goal = 100%) |
| `createGoal` / `updateGoalPending` / `transfer` / `deleteRedistributing` / `withdraw` | Create / pending edit / transfer / delete redistrib / withdrawal |

`Goal` / `GoalValidationService` use tip `GoalInflationFormulas` directly. `LedgerEngineCore` formula helpers delegate to the same APIs (single source).

## Keep-both with tip (PIP-103 / PIP-101 / PIP-102 / PIP-100 / PIP-99 / PIP-97)

Rebased onto `main@b5596e8e` (PIP-103 #37).

| Surface | Owner |
|---------|--------|
| `GoalInflationFormulas` | Tip PIP-97 — shared inflation / required-savings formulas |
| `protocol LedgerEngine` + `StubLedgerEngine` | Tip PIP-102/103 — Goals Sync/Update + History Save / create-goal |
| `StubLedgerService` | Tip PIP-101 — Opening lock + one-goal skip (no duplicate Opening) |
| History open→save (`customSplit`, create goal, suggested standing) | Tip PIP-103 — via `CreditEntryService` + stub Save APIs |
| `LedgerEngineCore` + `LedgerEngineCoreTests` | PIP-98 — pure mutation engine + formula facades |
| `LedgerFacade` → `LedgerEngineCore.BalanceSource` | Setup Accounts/Consent (PIP-99); maps fetched/typed |
| `UpdateBalanceRoutingService` / `resolvedIsTyped` | Tip PIP-100 — Update balance routes / History shape |

`StubLedgerEngine.processBalanceUpdate` applies pending goal edits (PIP-102), then delegates the higher-balance credit write to `LedgerEngineCore.applyBalanceDelta`. History Save / create-goal stay on tip PIP-103 (`CreditEntryService`) — no duplicate open/save path in Core.

## Acceptance criteria

- [x] Snapshot / delta (fetch vs typed)
- [x] History entry open → save; append-only slices
- [x] Standing split (1 goal = 100%)
- [x] Create / update (pending edits) / transfer / delete redistribution / withdrawal
- [x] Formulas: adjusted target, required savings, on-track status (via `GoalInflationFormulas`)
- [x] `cd PiPlanner && swift test` green
- [x] No new screens; DesignTokens / Pi* components untouched
- [x] Coexists with tip Opening/`StubLedgerService` + History open→save + `StubLedgerEngine` + `LedgerFacade` + PIP-100 + PIP-97

## Design refs

- UX strategy: https://docs.google.com/document/d/1T6kefFCbtehKp2bqV_h5OmMzsqu2yNWBgzrEJ_Ay1_A/edit
- Assignment notes: https://docs.google.com/document/d/1CwUJLF1rPHBA9IfzNasSM95sBVngoZpLp0FzdQPCyAk/edit
- Tracker: https://docs.google.com/spreadsheets/d/1je-IuGBFSuRUET4nAV_CEK65KZGS7V2kJh0u4dr3k7k/edit
- Linear: https://linear.app/telco-paytm/issue/PIP-98/ledger-engine-unit-tests

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

PIP-99…108 screens (beyond coexistence); food-delivery; merging this PR; marking Linear Done.
