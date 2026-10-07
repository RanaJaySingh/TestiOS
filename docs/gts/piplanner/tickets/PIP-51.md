# PIP-51 [iOS] Implement Standing split screen

Ticket: https://linear.app/telco-paytm/issue/PIP-51/ios-implement-standing-split-screen

## Delivered

Standing split (frame 15) under `PiPlanner/Views/Goals/StandingSplitView.swift` with `StandingSplitViewModel`, Linux-testable `StandingSplitService` (BR-2 / BR-4 / R12), persistence of `standingSplits` + `Goal.shareOfNewCredits` without rewriting saved amounts, Settings entry from Goals gear, one-goal skip (100% automatic), and unit tests for 100% validation + next-credit percentages.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R12 Standing split always usable at 100% | `StandingSplitService.isValidHundredPercent` + Save gated via `canSave` |
| Spec BR-2 Splits always total 100% | Running total / shortfall via `OpeningSplitService` helpers |
| Spec BR-4 Applies at next credit | Persist shares only; copy **"Change saved. Applies at the next credit."**; `percentagesForNextCredit` for PIP-47 |
| Frame 15 multi-goal edit | Editable % fields; **"Saved money stays put"** |
| One goal skip | `shouldPresentEditor` false; auto 100% via `applySingleGoalSkip` |
| Entry | Settings → Standing split (gear on Goals); additive wiring only |

## Acceptance criteria

- [x] Given two+ goals, when Standing split (15) opened, then percentages editable
- [x] Given percentages, when they sum to 100%, then Save is enabled
- [x] Given percentages, when they sum ≠ 100%, then Save disabled with running total shown
- [x] Given one goal, when standing split UI would show, then it is skipped (100% automatic)
- [x] Given standing split saved, when next credit arrives, then it uses these percentages (`percentagesForNextCredit`)
- [x] Given copy text, when shown, then "Saved money stays put" message visible
- [x] States: Multi-goal edit, One goal skip, Valid, Invalid
- [x] Tests: Unit test for 100% validation (`StandingSplitServiceTests`)

## Test results

`cd PiPlanner && swift test` — **109 tests, 0 failures** after rebase onto PIP-47 (includes 11 `StandingSplitServiceTests` + CreditEntryServiceTests). ViewModel tests run under Xcode only.

## How to run tests

```bash
cd PiPlanner
swift test
```

On macOS with Xcode (includes ViewModel tests):

```bash
cd PiPlanner
xcodebuild -scheme PiPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Assumptions

- Entry point is Settings (Goals gear), matching Spec §4.3 (no Settings tab) and ticket guidance.
- One-goal skip shows a non-editable confirmation (100% auto-applied) rather than the multi-goal editor; Save is not shown.
- Next-credit consumption: persisted `standingSplits` / `shareOfNewCredits` are read by PIP-47 `CreditEntryService.defaultPercentages`; also exposed as `StandingSplitService.percentagesForNextCredit(from:)`.
- Design artifact frame 15 was not scraped; copy follows PRD R12 + Spec BR-4 wording.

## Rebase notes

- Rebased onto `main` @ `c16068c` after PIP-47 Credit* merge (and earlier PIP-49 Goal detail).
- Conflict resolutions:
  - `GoalsViewModel.swift` — kept PIP-47 credit-flow properties/sheets; retained `standingSplits` + public `persistence` for Standing split / Settings.
  - `GoalsTabView.swift` — additive: Credit Sync/Update/Entry sheets + open-entry banner from PIP-47; Settings → Standing split entry from PIP-51.
  - `project.pbxproj` — kept both Credit* and StandingSplit* file refs / build phases.
- Did not rewrite Credit* or DeleteGoal*.

## Out of scope

This-credit-only overrides (owned by PIP-47), Delete goal (PIP-53), Goal detail rewrite (PIP-49 already landed).
