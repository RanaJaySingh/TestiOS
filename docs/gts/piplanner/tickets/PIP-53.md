# PIP-53 [iOS] Implement Delete goal flow

Ticket: https://linear.app/telco-paytm/issue/PIP-53/ios-implement-delete-goal-flow

## Delivered

Delete goal reassignment under `PiPlanner/Views/Goals/DeleteGoalView.swift` (+ `DeleteGoalFlow` entry), `DeleteGoalViewModel`, pure `DeleteGoalService`, History `goalDeleted` / “deleted / moved” entry, standing-split renormalization via shared `StandingSplitService`, only-goal gate (17e), mid-delete create with equal standing reset (17d). Goal detail Delete button wires to the real flow (replaces `GoalDeleteStubView`).

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R13 / BR-9 Delete reassigns money | `DeleteGoalService.applyDeletion` — equal default, edit once, confirm |
| BR-2 splits total 100% | Reuses `OpeningSplitService` validation / paisa allocation |
| Standing split renormalises | `StandingSplitService.renormalize` (additive on PIP-51 service) |
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

## Parallel work / merge order

**Stacks on PR #12 (PIP-51).** Branch is rebased onto `cursor/pip-51-standing-split-ba09` @ `98297e6`. PR base remains `main`; **merge after #12** so the diff shrinks to PIP-53-only once Standing split lands.

- Kept PIP-51 `StandingSplitService` as the single source of truth; added Delete helpers (`equalSplits` / `equalFractions` / `renormalize` / `applyShares` / UUID `equalDisplayPercents`).
- Kept PIP-47 `Credit*` sheets and PIP-51 Settings → Standing split entry in `GoalsTabView` / `SettingsView` (additive only).
- Goal detail Delete destination → `DeleteGoalFlow`; `allGoals` seeded from Goals tab.
- No second `StandingSplitService` type/file; `project.pbxproj` has one StandingSplitService entry set (PIP-51 IDs).

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

Transfer UI; Standing split screen ownership (PIP-51); credit entry ownership (PIP-47); rewriting Goal detail wholesale.
