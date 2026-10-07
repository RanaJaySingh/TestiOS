# PIP-47 [iOS] Implement Sync/Update balance and credit entry flow

Ticket: https://linear.app/telco-paytm/issue/PIP-47/ios-implement-syncupdate-balance-and-credit-entry-flow

## Delivered

Sync / Update / Credit-entry surfaces wired into the real Goals tab (PIP-45 + PIP-49 on main), with collision-safe Credit* type names and a pure `CreditEntryService` state machine (Linux-testable).

| Type / file | Role |
|-------------|------|
| `CreditEntryService` | Balance compare, open entry, lock once, BR-6 block, standing split option |
| `CreditSyncSheet` + `CreditSyncViewModel` | Frames 10 / 10a / 10b |
| `CreditUpdateBalanceSheet` + `CreditUpdateBalanceViewModel` | Frames 11a–11c / typed 13t |
| `CreditEntryView` + `CreditEntryViewModel` | Frames 13 / 13a–13g / 13t |
| `OpenEntryBanner` | Frame 9b Assign now |
| `CreditFlowHostView` | Optional embeddable host (Goals tab uses sheets directly) |
| `GoalsTabView` / `GoalsViewModel` | Hosts banner + Credit* sheets; keeps PIP-49 GoalDetail `NavigationLink` |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R7 Sync / Update / typed → open entry | `processFetchedBalance` + `createOpenCreditEntry` (`isTyped`) |
| R26 Same balance no-op | `.same` → `"No new credit since the last sync."`; no History write |
| 10b Lower → Withdrawal | `.withdrawalRequired` + stub callback (full Withdrawal UI out of scope) |
| R8 / BR-5 Save and lock once | `applyCreditLock`; second lock rejected |
| Use this split checkbox | `useThisSplitForStanding` updates `standingSplits` + `shareOfNewCredits` |
| R9 / BR-6 Open-entry banner | `OpenEntryBanner` on Goals + `canTapBalanceAction` |
| 13e One goal | `defaultPercentages` / UI auto 100% |
| BR-2 Splits 100% | Reuses `OpeningSplitService` validation |

## Acceptance criteria

- [x] Sync higher balance → open History entry (13) created
- [x] Same balance (10a) → "No new credit" message; no entry
- [x] Lower balance (10b) → Withdrawal stub callback
- [x] Open entry: edit % + Save → locked (13a/13d); BR-5 one edit
- [x] "Use this split" checked → standing split updated
- [x] Open entry pending → banner "Assign now" (9b)
- [x] Banner visible → Sync/Update blocked (BR-6)
- [x] One goal (13e) → 100% auto-assigned
- [x] States: Sync new, Same, Lower, Open, Locked, Banner
- [x] Unit tests: split validation + entry state machine

## Rebase notes

- Rebased onto `main` @ `93e6284` (PIP-45 Goals tab + PIP-49 Goal detail merged).
- Replaced PIP-45 stub call sites in `GoalsTabView` (`SyncSheet` / `GoalsUpdateBalanceSheet`) with `CreditSyncSheet` / `CreditUpdateBalanceSheet` / `CreditEntryView` / `OpenEntryBanner`.
- Kept PIP-49 `GoalsRoute.detail` → `GoalDetailView(...)` navigation (history / heldChanges / standingSplits / persistence) intact.
- Stopped using `GoalsTabPlaceholderView` (removed from main with PIP-45); setup flows already land on `MainTabView`.
- Left unused stub files `SyncSheet.swift` / `UpdateBalanceSheet.swift` in tree to avoid noisy deletes; call sites no longer reference them.

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Full Withdrawal UI; Goal detail CRUD beyond PIP-49.
