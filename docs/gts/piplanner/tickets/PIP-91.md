# PIP-91 [iOS] History tab list visual

Ticket: https://linear.app/telco-paytm/issue/PIP-91/ios-history-tab-list-visual

## Delivered

History tab list restyle (frames 12 / 12a list chrome) so newest-first rows show design type labels, amounts, and lock icons on saved entries — **without** ViewModel / ordering / lock-logic changes.

| Type / file | Role |
|-------------|------|
| `Views/History/HistoryEntryRow.swift` | `PiCard` rows; type icon well; `PiIcons.lock` on saved; open vs locked chrome; `PiTypography` / `PiColors` amounts |
| `Views/History/HistoryTabView.swift` | App background; empty-state tokens; plain list with card insets (no separators) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R15 History tab list | Rows: type label + amount + lock on saved |
| Spec §3.5 HistoryRow | Same visual contract via `HistoryEntryRow` |
| Spec §4.2 J6 | Frames 12 / 12a list chrome |
| Spec §3.3 Lock | `PiIcons.lock` (`lock.fill`) |
| Open vs locked chrome | Open: navy accent bar + light-blue “Assign now” chip + navy amount; Locked: lock icon + quieter well |
| Empty list | Tokenised empty state (`history.empty`) |
| PIP-67 / PIP-69 / PIP-71 | Tokens, `PiCard`, `PiIcons` — no new hex / MainTab chrome |

## Acceptance criteria

- [x] Given History tab, When entries list, Then newest-first rows show type labels, amounts, and lock icons on saved entries consistent with design
- [x] States handled: empty list; open vs locked row chrome
- [x] Tests: History tests green; `cd PiPlanner && swift test` all green (Reviewer screenshot / side-by-side checklist below)

## Reviewer checklist (History list)

Compare simulator/device to design artifact frames 12 / 12a:

1. List sits on light app background (`#F5F7FB`), white card rows (radius 22, soft shadow).
2. Each row: type icon in light-blue circle, type label (semibold), trailing ₹ amount (Indian grouping unchanged).
3. Saved / locked rows show `lock.fill` (`PiIcons.lock`) next to the type label; no navy leading accent bar.
4. Open New credit row: navy leading accent + “Assign now” light-blue chip; amount in navy; **no** lock icon.
5. Empty History: clock metaphor (`PiIcons.historyTab`) in light-blue well + empty copy.
6. Tapping open credit still opens editable entry; tapping locked still opens read-only detail (behaviour unchanged).

## References

- PRD R15: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2 J6 / §3.5 HistoryRow: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 12, 12a: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (components), PIP-71 (icons)

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22 / PIP-71 icons). Touches **only** `HistoryTabView` + `HistoryEntryRow` — no MainTab chrome, ViewModel, or HistoryService behaviour edits (PIP-85 owns entry detail open/locked visual).

## Test results

`cd PiPlanner && swift test` — see PR / CI; HistoryServiceTests unchanged (behaviour preserved).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

History ordering / lock / destination logic (PIP-59 Done); History entry detail open vs locked visual (PIP-85); MainTab chrome; ViewModel / product behaviour; Android twin (PIP-92).
