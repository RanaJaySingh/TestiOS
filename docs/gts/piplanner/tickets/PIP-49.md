# PIP-49 [iOS] Implement Goal detail and edit screens

Ticket: https://linear.app/telco-paytm/issue/PIP-49/ios-implement-goal-detail-and-edit-screens

## Delivered

Navigable `GoalDetailView` (frame 14) and `GoalEditView` (frame 6e) under `PiPlanner/Views/Goals`, with `GoalDetailViewModel` / `GoalEditViewModel`, pure `GoalHeldChangeService` + `HeldGoalChange` model (BR-4 / R11 / R24), optional `PersistedAppState.heldGoalChanges`, Transfer/Delete stub destinations, and unit tests.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R10 Goal detail metrics + From History | `GoalDetailView` + `GoalDetailViewModel` |
| R11 / R24 / BR-4 edits apply at next credit | `GoalHeldChangeService.commitEdit` — History unchanged; held marker recorded |
| Toast 9c | `GoalHeldChangeService.toastMessage` → detail overlay after save |
| Held info 13g | Banner on detail when `hasHeldChange` |
| Edit 6e saved amount locked | `GoalEditView` locked row; `applyEdit` ignores draft.savedAmount |
| Transfer / Delete nav | `GoalTransferStubView` / `GoalDeleteStubView` (full flows out of scope) |

## Acceptance criteria

- [x] Goal detail (14): saved, status, adjusted target, monthly need, dates, inflation, share visible
- [x] From History lists related history entries
- [x] Transfer / Edit / Delete navigate (Transfer/Delete stubs; Delete flow out of scope)
- [x] Goal edit (6e): saved amount field locked (read-only)
- [x] On save → toast "Change saved. Applies at next credit." (9c / BR-4)
- [x] Later view shows edit-held info (13g)
- [x] States: Detail view, Edit mode, Post-edit toast
- [x] Unit test for held changes logic

## Parallel work / rebase note

Rebased onto `main` @ `b7e9549` (PIP-45 merge). Conflict in `Views/Goals/GoalDetailView.swift`: kept PIP-49 real screen; discarded PIP-45 stub.

- `GoalsTabView` → `GoalDetailView(goal:formattedSaved:statusLabel:history:heldChanges:standingSplits:persistence:)` (compatible init + wiring).
- `GoalsViewModel` exposes `history` / `heldGoalChanges` / `standingSplits` / `persistence` for detail/edit.
- Sync/Update stubs and `MainTabView` left intact aside from this navigation wiring.
- Xcode project: single `GoalDetailView` file ref (PIP-45 IDs); added `GoalEditView` + held-change sources.

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

- Toast copy follows ticket AC (no “the”): `Change saved. Applies at next credit.` Spec BR-4 uses “the next credit.”
- Goal fields update immediately for the next credit; locked History allocations are never rewritten; `heldGoalChanges` drives 13g until cleared by PIP-47 on credit apply.
- `PersistedAppState.heldGoalChanges` defaults to `[]` when decoding older JSON.
- Transfer/Delete are stub screens only.
- Design artifact frames 14 / 6e not fully scraped; layout follows PRD screen list + existing GoalForm patterns.

## Out of scope

Full Delete flow; Transfer UI; Goals tab layout (PIP-45); Sync/credit apply clearing held changes (PIP-47).
