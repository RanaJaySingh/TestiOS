# PIP-81 [iOS] Goals home navy card, quick actions, banner, header chrome

Ticket: https://linear.app/telco-paytm/issue/PIP-81/ios-goals-home-navy-card-quick-actions-banner-header-chrome

## Delivered

Goals home visual restyle (frames 9 / 9b / 9c / 11) — navy balance card, quick-action row, open-credit banner, richer goal cards, and chrome-only header icons — using PIP-67 tokens, PIP-69 components, and PIP-71 `PiIcons`. **No ViewModel / sync / credit product-behaviour changes.**

| Type / file | Role |
|-------------|------|
| `Views/Goals/BalanceCard.swift` | Navy gradient card; white amount; last-synced / last-updated line; Sync / Update balance CTA |
| `Views/Goals/QuickActionRow.swift` | Sync/Update · New goal · Transfer · History chips (`PiIcons`) |
| `Views/Goals/GoalCard.swift` | `PiCard` surface; saved/of target; status chip; monthly need; % of credits |
| `Views/Goals/OpenEntryBanner.swift` | Frame 9b Assign now (light-blue surface + navy CTA) |
| `Views/Goals/GoalsTabView.swift` | Layout wiring + header Search / notifications / chart chrome |
| `Views/Main/MainTabView.swift` | History quick action → existing History tab |
| `Services/GoalsTabService.swift` | Presentation helpers (Linux-testable labels only) |
| `GoalsTabServiceTests` | New label / last-activity cases |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R10 navy balance card + last-synced/updated | `BalanceCard` + `GoalsTabService.lastBalanceActivityLine` |
| R10 quick actions Sync/Update, New goal, Transfer, History | `QuickActionRow` → existing Sync/Update sheets, Goal form sheet, Transfer route, History tab |
| R10 goal cards saved/of target, status, monthly need, % credits | `GoalCard` + `GoalsTabService` label helpers |
| R10 / 9b open-credit banner | `OpenEntryBanner` Assign now treatment |
| R20 / A2 header Search / notifications / bar_chart | Toolbar images via `PiIcons.header*` — chrome only, no flows |
| Consent On vs Off | Sync vs Update (card CTA “Update balance”; quick action “Update”) |

## Acceptance criteria

- [x] Given Goals tab after setup, When home renders, Then navy balance card with last-synced/updated line; quick actions Sync or Update, New goal, Transfer, History; goal cards show saved/of target, status, monthly need, % of credits
- [x] Given open credit, When banner shows, Then Assign now treatment matches design 9b (light-blue + navy CTA)
- [x] Given header Search/notifications/bar_chart, When shown, Then chrome-only (no new flows) per A2/R20
- [x] States: consent On (Sync) vs Off (Update); with/without open entry
- [x] Tests: Goals behaviour tests green; `cd PiPlanner && swift test` all green

## Reviewer checklist (Goals home)

Compare simulator/device to design frames 9 / 9b / 9c / 11:

1. Balance card is navy (not gray system card); amount in white; last-synced (consent On) or last-updated (consent Off) caption present.
2. Quick-action row: Sync/Update, New goal, Transfer, History with Material-metaphor SF icons from `PiIcons`.
3. Goal cards white radius ~22; show “₹ saved of ₹ target”, On track/Behind chip (token green/amber), monthly need, “N% of credits”.
4. Open credit → light-blue banner + Assign now (still opens existing credit entry).
5. Header shows Search, notifications, chart (non-interactive chrome) + Settings gear (existing).
6. No new navigation from header chrome icons.

## References

- PRD R10, R20: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2 J2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 9, 9b, 9c, 11: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69, PIP-71

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22; includes PIP-71 icons). Rebased onto `main@bb206d4` (PIP-95 #28; includes PIP-87 / PIP-91 / PIP-85). Keep-both: Goals home visuals preserved; History entry/list / CreditEntryView left unchanged from main. Touch only Goals home / BalanceCard / GoalCard / banner / header chrome (+ `GoalsTabService` presentation helpers + `MainTabView` History tab callback). Prefer `PiIcons` for header icons; did not redefine icon mapping.

## Test results

`cd PiPlanner && swift test` — **211 tests, 0 failures** (on tip `d62bb15` over `bb206d4`; includes new `GoalsTabServiceTests` presentation cases).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Sync/credit logic changes; new header behaviours/flows; ViewModel product behaviour; Android twin (PIP-82); Goal detail / Sync sheet visual tickets.
