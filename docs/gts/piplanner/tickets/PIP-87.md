# PIP-87 [iOS] Goal detail visual parity

Ticket: https://linear.app/telco-paytm/issue/PIP-87/ios-goal-detail-visual-parity

## Delivered

Restyled `GoalDetailView` (frame 14) to match PRD R13 / design layout using PIP-67 `DesignTokens` / `PiColors` / `PiTypography` and PIP-69 `PiCard` + PIP-71 `PiIcons`. **Visual / layout only** — no ViewModel, service, or CRUD/transfer/delete behaviour changes.

| Surface | Treatment |
|---------|-----------|
| Screen background | `PiColors.backgroundApp` + `.piPlannerTheme()` |
| Large saved amount | Hero in `PiCard` — `PiTypography.amountHero()` + navy |
| On track / Behind | Status chip — `PiColors.positiveGreen` vs `PiColors.behind` |
| Metrics | `PiCard` rows: Target, Adjusted target, **% reached**, Monthly need, Start/End, Inflation, Share |
| Actions | Transfer / Edit / Delete outline actions (`PiIcons.transfer`; destructive Delete) |
| From History | Section title + `PiCard` rows with `PiIcons.lock` on locked entries |
| Held info (13g) | Light-blue chip-surface banner (same copy / gate) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R13 Goal detail visual parity | `Views/Goals/GoalDetailView.swift` restyle |
| Spec §4.2 J3 frame 14 | Detail metrics + actions + From History hierarchy |
| Tokens / components | `DesignTokens`, `PiColors`, `PiTypography`, `PiCard`, `PiIcons` |
| % reached | View-local presentation: `saved ÷ adjustedTarget` via `GoalValidationService.displayPercent` (no ViewModel API change) |

## Acceptance criteria

- [x] Given Goal detail, When opened, Then large saved amount, Behind/On track, adjusted target, % reached, monthly need, dates, inflation, share line, From History list, and Transfer/Edit/Delete actions match design layout
- [x] States: On track vs Behind status chrome (`goals.detail.status.onTrack` / `.behind`)
- [x] Tests: goal detail behaviour tests green; `cd PiPlanner && swift test` all green
- [x] Out: CRUD/transfer/delete logic unchanged; no ViewModel/product-behaviour changes

## Accessibility IDs preserved

`goals.detail`, `goals.detail.heldInfo`, `goals.detail.metrics`, `goals.detail.dates`, `goals.detail.transfer`, `goals.detail.edit`, `goals.detail.delete`, `goals.detail.history`, `goals.detail.toast` (+ status chrome ids above).

## References

- PRD R13: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frame 14: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components)
- Related: Android twin PIP-88

## Parallel work / base

Started from `b30a048` (PIP-69 on main). **Touch only** `GoalDetailView` (+ this ticket doc) so parallel visual tickets (PIP-73..95) rebase cleanly. Edit form chrome left to PIP-79 / shared surface tickets — not on the detail scroll surface.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures**.

## How to run tests

```bash
cd PiPlanner
swift test
```

SwiftUI previews: `#Preview("On track")` / `#Preview("Behind")` on `GoalDetailView`.

## Out of scope

ViewModel / service changes; Transfer / Edit / Delete product flows (PIP-49/53/55 Done); GoalEditView restyle; Goals home / GoalCard (PIP-81); Android (PIP-88).
