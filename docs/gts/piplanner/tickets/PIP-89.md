# PIP-89 [iOS] Standing split, Transfer, Withdrawal, Delete sheets visual

Ticket: https://linear.app/telco-paytm/issue/PIP-89/ios-standing-split-transfer-withdrawal-delete-sheets-visual

## Delivered

Visual restyle of Standing split, Transfer, Withdrawal, and Delete goal sheets to design hierarchy, light-blue amount chips, and negative-amount treatment — **without** ViewModel / allocation / validation behaviour changes.

| File | Role |
|------|------|
| `Views/Goals/StandingSplitView.swift` | Frame 15 — PiSheet chrome, PiCard % rows, PrimaryCTA Save (disabled until 100%) |
| `Views/Goals/TransferView.swift` | Frames 16 / 16b — From/To + amount PiCards, LightBlueChip ₹1,000/₹5,000/₹10,000, After transfer preview, PrimaryCTA Move |
| `Views/Goals/WithdrawalView.swift` | Frames 18 / 18a — PiSheet, reductions as −₹ (destructive), PrimaryCTA Save and lock; RecordWithdrawalSheet chrome |
| `Views/Goals/DeleteGoalView.swift` | Frame 17 — release amount hero, destination split PiCards, destructive Confirm delete CTA |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R14 sheets 15 / 16 / 18 | Title/helper via `PiSheet`; % / amount rows; Transfer chips; withdrawal negatives |
| PRD Delete frame 17 | Release amount + destination split + destructive confirm |
| Tech Spec §4.2 J3–J5 | Goal CRUD sheets + Transfer + Withdrawal visual must-match |
| Spec §3.5 components | `PiSheet`, `PiCard`, `LightBlueChip`, `PrimaryCTA`, `SecondaryCTA` + `DesignTokens` / `PiColors` / `PiTypography` |

## Acceptance criteria

- [x] Given Standing split, When shown, Then % fields and Save at 100% chrome match design (PrimaryCTA disabled look when total ≠ 100%)
- [x] Given Transfer, When shown, Then From/To, chips ₹1,000/₹5,000/₹10,000 (LightBlueChip), After transfer preview match design
- [x] Given Withdrawal, When shown, Then goal reductions and negative amounts match design; Save and lock CTA styling matches
- [x] Given Delete goal, When shown, Then release amount, destination split, confirm destructive layout match design
- [x] States: invalid totals (CTA disabled look); valid totals
- [x] Tests: transfer/withdrawal/delete/standing service (+ Linux suite) green; `cd PiPlanner && swift test` all green

## Reviewer checklist

Compare simulator/device to design frames 15, 16, 16b, 17, 18, 18a:

1. Standing split — sheet chrome, % rows on cards, Save navy CTA enabled only at 100%.
2. Transfer — From/To cards, light-blue ₹ chips (selected stroke when amount matches), After transfer preview with source↓ / dest↑ colour cues, Move CTA.
3. Withdrawal — shortfall / reductions as −₹ in destructive red; Save and lock navy PrimaryCTA; disabled when invalid.
4. Delete — released ₹ hero, Move to % rows, red Confirm delete (disabled when split invalid).

## Consumption (components)

```swift
PiSheet(title: "Transfer", helper: TransferService.caption) { … }
PiCard { … }
LightBlueChip(title: "₹5,000", isSelected: true) { … }
PrimaryCTA(title: "Save", isEnabled: viewModel.canSave) { … }
SecondaryCTA(title: "Add another goal", style: .text) { … }
```

Do **not** change ViewModels / services / money logic in this ticket.

## References

- PRD R14 (+ Delete frame 17): https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2 J3–J5: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 15, 16, 16b, 17, 18, 18a: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared visual components)

## Parallel work / base

Started from `b30a048` (PIP-69 shared components on main). Touches **only** StandingSplit / Transfer / Withdrawal / DeleteGoal view files + this ticket doc — rebase-friendly vs PIP-73..95.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures** (includes StandingSplit / Transfer / Withdrawal / DeleteGoal service suites; Views excluded from Linux SPM like other SwiftUI screens).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Allocation/validation logic (Done PIP-51/53/55/57); ViewModel/product-behaviour changes; Android twin (PIP-90); other visual tickets (PIP-73..95).
