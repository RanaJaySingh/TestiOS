# PIP-59 [iOS] Implement History tab

Ticket: https://linear.app/telco-paytm/issue/PIP-59/ios-implement-history-tab

## Delivered

History tab under `PiPlanner/Views/History/` with pure `HistoryService` (Linux-testable), `HistoryViewModel`, `HistoryEntryRow`, `HistoryDetailView` (read-only 12a), and `HistoryTabView` wired from `MainTabView` with persistence. Reuses existing `HistoryEntry` writers from Opening / Credit / Transfer / Withdrawal / DeleteGoal — no writer rewrites.

| Type / file | Role |
|-------------|------|
| `HistoryService` | Newest-first sort, type labels/icons, open vs locked, destination, amounts, “Original amounts never change” |
| `HistoryViewModel` | Loads history/goals; presents open credit sheet |
| `HistoryEntryRow` | List row: icon, label, lock, subtitle, date, amount |
| `HistoryDetailView` | Read-only locked / Opening balance detail (12a) |
| `HistoryTabView` | Empty / list; open credit → `CreditEntryView`; locked → detail |
| `MainTabView` | Passes `persistence` into History (additive; no tab-bar rewrite) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R16 / R23 History read-only after lock | `HistoryService.isReadOnly` / `destination` → `HistoryDetailView` |
| Frame 12 newest first | `HistoryService.sortedNewestFirst` |
| Type icons/labels | `typeLabel` / `systemImageName` for all five kinds |
| Lock icons on saved | `showsLockIcon` → `lock.fill` on row + detail |
| Open Assign now → edit credit | `canEditAsCredit` → sheet `CreditEntryView` |
| 12a Original amounts never change | `HistoryService.originalAmountsCaption` on detail |
| Opening balance always read-only | `isReadOnly` true when `type == .openingBalance` |
| Empty / With entries / Open vs Locked | `HistoryTabView` empty state + list + destination |

## Acceptance criteria

- [x] Given History tab (12), when displayed, then entries shown newest first
- [x] Given entry types, when shown, then icons/labels distinguish: Opening balance, New credit, Transfer, Withdrawal, Goal deleted
- [x] Given saved entries, when displayed, then lock icons visible
- [x] Given open "Assign now" entry, when tapped, then navigates to editable credit entry
- [x] Given saved/locked entry (12a), when tapped, then read-only view shows "Original amounts never change"
- [x] Given Opening balance entry, when tapped, then it is always read-only
- [x] States handled: Empty, With entries, Open vs Locked
- [x] Tests: unit tests for list ordering / open vs locked / read-only; UI tests for list + caption (Xcode)

## Parallel work / base

Started from `main` @ `3f91f3d` (PIP-55 Transfer). Additive only — Transfer / Withdrawal / DeleteGoal / StandingSplit / Credit writers untouched. `MainTabView` change is a single `HistoryTabView(persistence:)` argument (PIP-61 Settings can still touch gear / Settings without conflict).

## How to run tests

```bash
cd PiPlanner
swift test
```

**Result:** 158 tests, 0 failures (includes 10 `HistoryServiceTests`; ViewModel / UITests are Xcode-host only).

## Assumptions

- History type label for deletions is **Goal deleted** (AC); writer copy `DeleteGoalService.historyTitle` (“Deleted / moved”) unchanged.
- Open New credit uses the existing `CreditEntryView` sheet (same as Goals Assign now); locked credits use `HistoryDetailView` so 12a caption is “Original amounts never change” (distinct from Opening’s “Locked amounts never change” in credit/opening flows).
- Transfer row subtitle reuses `TransferService.historyTitle` (“From → To · ₹amount”).

## Out of scope

Rewriting Credit / Transfer / Withdrawal / DeleteGoal flows; Settings tab (PIP-61); Ask tab (PIP-63).
