# PIP-83 [iOS] Sync / Update sheets visual parity

Ticket: https://linear.app/telco-paytm/issue/PIP-83/ios-sync-update-sheets-visual-parity

## Delivered

Post-setup Sync and Update balance sheets restyled to Paytm-like hierarchy using PIP-69 components + PIP-67 tokens — **without** ViewModel or product-behaviour changes.

| Type / file | Role |
|-------------|------|
| `Views/Goals/CreditSyncSheet.swift` | Frames 10 / 10a / 10b — PiSheet “Balance sync”, PiCard Previous / Fetched / New amount (+green) or Went down by, PrimaryCTA actions |
| `Views/Goals/CreditUpdateBalanceSheet.swift` | Frames 11a–11c — PiSheet choice/manual/PIN chrome; PrimaryCTA Manually / Check balance / Continue; SecondaryCTA Balance sync / Record a withdrawal / Back |

## Visual map (design extract)

| Frame | Hierarchy |
|-------|-----------|
| 10 credit up | Previous · Fetched · **New amount +₹…** (`PiColors.positiveGreen`) → Continue |
| 10a same | Previous · Fetched + secondary info (“No new credit…”) |
| 10b down | Previous · Fetched · Went down by −₹… (destructive) + info → Continue to withdrawal |
| 11a Update | Current amount card · Manually (primary) · Balance sync (outline) · optional Record a withdrawal (text) |
| 11b Manual | ₹ field in PiCard · Continue / Back |
| 11c PIN | Demo helper · navy pin dots · light-blue pad · Check balance / Back |

## Acceptance criteria

- [x] Given Sync sheet, When open, Then Previous / Fetched / New amount (+green) layout matches design
- [x] Given same-balance or went-down messaging, When shown, Then hierarchy matches design
- [x] Given Update balance from Goals, When open, Then Paytm-like choice/amount chrome matches design
- [x] States: credit up / same / down messaging visuals
- [x] Tests: sync/update behaviour tests green; `cd PiPlanner && swift test` all green

## Reviewer checklist

Compare simulator/device to design frames 10 / 10a / 10b / 11a:

1. Sync sheet uses PiSheet handle + title **Balance sync** (not ad hoc NavigationStack-only chrome).
2. Balance rows sit in a white `PiCard` (radius 22).
3. New amount shows **+₹…** in positive green `#1B8A4A` (not system green / navy).
4. Same / down messaging is body secondary (or destructive for went-down amount); no invented badges.
5. Update balance 11a: Manually = filled navy PrimaryCTA; Balance sync = outline SecondaryCTA.
6. Accessibility ids preserved: `credit.syncSheet`, `creditSync.confirm|continue|withdrawal|info`, `credit.updateBalanceSheet`, `creditUpdate.manual|pin|digits|apply|recordWithdrawal|info`.

## References

- PRD R11: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 10, 10a, 10b, 11a: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components)

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22). Touched only `CreditSyncSheet` / `CreditUpdateBalanceSheet` (+ this ticket doc). Avoided Theme/Components/MainTab edits for rebase-friendliness with PIP-73..95.

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Sync/credit entry logic (Done in PIP-47); ViewModel/product behaviour; setup Update balance (frame 4 / PIP-77); Android twin (PIP-84).
