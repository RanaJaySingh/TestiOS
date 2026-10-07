# PIP-53 [iOS] Implement Delete goal flow

Ticket: https://linear.app/telco-paytm/issue/PIP-53/ios-implement-delete-goal-flow

## Delivered

Delete goal reassignment under `PiPlanner/Views/Goals/DeleteGoalView.swift` (+ `DeleteGoalFlow` entry), `DeleteGoalViewModel`, pure `DeleteGoalService` + shared `StandingSplitService` (Linux-testable), History `goalDeleted` / “deleted / moved” entry, standing-split renormalization, only-goal gate (17e), mid-delete create with equal standing reset (17d). Goal detail Delete button wires to the real flow (replaces `GoalDeleteStubView`).

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R13 / BR-9 Delete reassigns money | `DeleteGoalService.applyDeletion` — equal default, edit once, confirm |
| BR-2 splits total 100% | Reuses `OpeningSplitService` validation / paisa allocation |
| Standing split renormalises | `StandingSplitService.renormalize` (shared with PIP-51) |
| Only-goal gate 17e | `requiresReplacement` / phase `.onlyGoalGate`; confirm disabled |
| Mid-delete create 17d | `addGoalDuringDelete(resetStandingToEqual:)` |
| History deleted / moved | Locked `HistoryEntryType.goalDeleted`; label via `DeleteGoalService.historyTitle` |
| Goal detail Delete hook | `GoalDetailView` `.delete` → `DeleteGoalFlow` (minimal change) |

## Acceptance criteria

- [x] Given Delete (17), when initiated, then reassignment UI shows with equal default distribution
- [x] Given reassignment, when editable once, then user can modify before confirm
- [x] Given reassignment, when confirmed, then money moves and History "deleted / moved" entry created
- [x] Given standing split, when delete confirmed, then it renormalizes across remaining goals
- [x] Given only one goal remaining (17e), when deleting, then confirm disabled until replacement created
- [x] Given create goal mid-delete (17d), when goal added, then standing split may reset to equal
- [x] States: Reassign default, Reassign edit, Confirm, Only-goal gate
- [x] Tests: Unit test for money reassignment and renormalization

## Parallel work / rebase note

Rebased onto `main` @ `93e6284` (PIP-49 Goal detail/edit merge). Kept PIP-49’s real `GoalDetailView`; replaced only the Delete stub destination with `DeleteGoalFlow`. Transfer stub unchanged.

- **PIP-49:** Delete button already navigates `GoalDetailRoute.delete` — hook is the destination swap + `allGoals` on `GoalDetailViewModel` for reassignment targets.
- **PIP-51 Standing split:** Use `StandingSplitService` (`equalSplits` / `renormalize` / `applyShares`) rather than duplicating math.
- **PIP-47:** Do not introduce `Credit*` file names (none added here).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Assumptions

- “Editable once” = one Edit → Done pass locks percentages until Confirm (default equal is usable without editing).
- Standing renormalization after delete is proportional to prior remaining shares; mid-delete create sets `resetStandingToEqual` so confirm applies equal standing.
- History presentation label for `goalDeleted` is “Deleted / moved” (`DeleteGoalService.historyTitle`).
- Design frames 17 / 17a–17e inferred from PRD R13 + Spec BR-9 (artifact not scraped in-agent).

## Out of scope

Transfer UI; Standing split screen (PIP-51); credit entry; rewriting Goal detail wholesale.
