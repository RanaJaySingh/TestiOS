# PIP-85 [iOS] History entry open vs locked visual

Ticket: https://linear.app/telco-paytm/issue/PIP-85/ios-history-entry-open-vs-locked-visual

## Delivered

Restyle of History credit-entry open / locked / typed treatments to design badges and split blocks (frames 13, 13a–13t). Visual / layout / token / component only — no ViewModel or lock/assign behaviour changes.

| Type / file | Role |
|-------------|------|
| `Views/Goals/CreditEntryView.swift` | Open Assign now · locked Saved and locked + lock · Typed/Custom badges · already-saved + this-credit `PiCard` blocks · `PrimaryCTA` |
| `Views/History/HistoryDetailView.swift` | Locked New credit detail: Saved and locked + badges + this-credit allocations card; other types get token chrome only |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R12 open Assign now | Header status `CreditEntryService.assignNowTitle` + navy title treatment |
| PRD R12 Saved and locked + lock | Locked header + `PiIcons.lock` |
| PRD R12 Typed / Custom badges | Light-blue chip badges (`PiColors.chipLightBlue`); Typed when `isTyped`; Custom when locked && !typed (13d) |
| Already-saved / this-credit blocks | Separate `PiCard` sections — “Already saved, not changing” vs “Split ₹… · This credit only” |
| Spec §4.2 J2 History entry | Consumes PIP-67 tokens + PIP-69 `PiCard` / `PrimaryCTA` + PIP-71 `PiIcons.lock` |
| 13t no Balance now | Typed path omits Previous / Balance now rows (unchanged behaviour) |

## Acceptance criteria

- [x] Given open entry, When shown, Then Assign now treatment matches design
- [x] Given saved/locked entry, When shown, Then Saved and locked + lock icon match design
- [x] Given Typed/Custom, When badges show, Then match design; already-saved and this-credit split blocks match layout
- [x] States handled: open / locked / typed
- [x] Tests: credit entry behaviour tests green; `cd PiPlanner && swift test` green

## Visual summary (Reviewer)

1. **Open** — navy “Assign now” title; amount card; already-saved card; this-credit split card with sliders; Save and lock primary CTA; caption “You can change this split once.”
2. **Locked** — “Saved and locked” + lock.fill; Custom badge (non-typed) or Typed badge; Done CTA; locked amounts caption.
3. **Typed (13t)** — Typed badge; Previous / Balance now omitted; New amount still shown.
4. Cards use white `PiCard` radius 22 + soft shadow; chips use light-blue token; app background `#F5F7FB`.

## Parallel work / base

Started from `b30a048` (visual-parity foundations on main). Touches only `CreditEntryView` + `HistoryDetailView` so parallel PIP-73..95 screen tickets stay rebase-friendly. No ViewModel / Service / History list row changes (list chrome is PIP-91).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Lock/assign logic (Done in PIP-47); History list rows (PIP-91); Goals home banner (PIP-81); ViewModel behaviour; Android twin PIP-86.

## References

- PRD R12: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 13, 13a–13t: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
