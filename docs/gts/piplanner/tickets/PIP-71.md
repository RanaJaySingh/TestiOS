# PIP-71 [iOS] Material-style icon mapping + tab bar chrome

Ticket: https://linear.app/telco-paytm/issue/PIP-71/ios-material-style-icon-mapping-tab-bar-chrome

## Delivered

Icon catalog + MainTabView selected-state chrome so Goals · History · Ask match Spec §3.3 metaphors and navy selected tint from PIP-67 — **without** new destinations or product-behaviour changes.

| Type / file | Role |
|-------------|------|
| `Theme/PiIcons.swift` | SF Symbol names for Spec §3.3 metaphors + `MainTabChrome` (3 tabs, selected/unselected, navy tint hex) |
| `Views/Main/MainTabView.swift` | TabView selection + filled selected icons + `.tint(PiColors.navyPrimary)` |
| `GoalsTabView` / History views / `HistoryService` | Consume catalog for settings / lock / history / credit·transfer·withdrawal (no behaviour change) |
| `PiIconsTests` | Catalog + MainTabChrome contract smoke (Linux `swift test`) |

## Icon map (Spec §3.3 → SF Symbol)

| Metaphor | SF Symbol (unselected / selected) |
|----------|-----------------------------------|
| Goals tab | `target` / `flag.fill` |
| History tab | `clock` / `clock.fill` |
| Ask tab | `bubble.left.and.bubble.right` / `.fill` |
| Settings gear | `gearshape` |
| Lock (saved) | `lock.fill` |
| Sync | `arrow.triangle.2.circlepath` |
| Transfer | `arrow.left.arrow.right` |
| Withdrawal / down | `arrow.down.circle` |
| New credit / add | `plus.circle` |
| Header Search / notifications / chart | `magnifyingglass` / `bell` / `chart.bar` (catalog only; chrome later on Goals home) |

## Tab chrome

- Exactly three tabs: **Goals · History · Ask** (no Settings tab).
- Selected: filled SF weight where available + navy tint `#0A2A6B` (`PiColors.navyPrimary` / `DesignTokens.Navy.primary`).
- Unselected: outline-leaning catalog symbols; system gray via TabView.

## Acceptance criteria

- [x] Given post-setup shell, When tab bar shows, Then exactly three tabs Goals · History · Ask in order with selected-state styling (navy tint + filled icons); no Settings tab
- [x] Given tabs/header actions/locks/sync/transfer/settings metaphors, When icons render, Then SF Symbols match Spec §3.3 (A4 equivalence; no emoji)
- [x] States handled: selected vs unselected tab (`MainTabChrome.Tab.systemImage(selected:)`)
- [x] Tests: `PiIconsTests` contract + Reviewer checklist below; behaviour tests green

## Reviewer checklist (MainTabView)

Compare simulator/device to design artifact tabs:

1. Tab order left→right: Goals, History, Ask only (no Settings).
2. Selected tab label/icon uses navy (not bright blue `#006BE8`, not purple).
3. Selected icon weight is filled (flag.fill / clock.fill / bubble…fill); unselected is outline-leaning.
4. Gear on Goals still opens Settings (existing behaviour); gear uses `PiIcons.settings`.
5. No new navigation from catalogued header Search / notifications / chart (not wired this ticket).

## References

- PRD R4, R5: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §3.3 / §3.4: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-67 (tokens)

## Parallel work / base

Started from `141a2bcc` (main after PIP-67). Icon catalog + MainTabView chrome only — avoided `Components/` shared card/CTA files (PIP-69 may land in parallel).

## Test results

`cd PiPlanner && swift test` — **202 tests, 0 failures** (includes 7 `PiIconsTests` for catalog + MainTabChrome).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

New navigation destinations; header Search/notifications/chart behaviour (chrome-only later — PIP-81); shared visual components (PIP-69); Android twin (PIP-72); money/ViewModel behaviour.
