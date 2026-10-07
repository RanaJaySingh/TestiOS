# PIP-77 [iOS] Update balance / UPI Demo chrome visual

Ticket: https://linear.app/telco-paytm/issue/PIP-77/ios-update-balance-upi-demo-chrome-visual

## Delivered

Paytm-like visual chrome for Update balance choice, Manual amount, and UPI PIN Demo (setup frames 4 / 4a–4e + Goals Update frames 11a–11c) using PIP-69 `PiSheet` / `PiCard` / `PrimaryCTA` / `SecondaryCTA` and PIP-67 tokens — **without** PIN validation / sync / ViewModel behaviour changes.

| Type / file | Role |
|-------------|------|
| `Views/Setup/UpdateBalanceUPIChrome.swift` | Shared choice rows, DEMO badge, bank masked line, PIN dots, mock pad |
| `Views/Setup/ConsentSheet.swift` | `UpdateBalanceSheet` choice rows; `OtherAppView` / `WrongPinView` CTAs + wrong-PIN visual |
| `Views/Setup/ManualBalanceView.swift` | ₹ amount in `PiCard`; navy `PrimaryCTA` enabled / disabled at ₹0 |
| `Views/Setup/UPIPinView.swift` | Demo badge, bank masked line, mock pad, Check balance / Cancel |
| `Views/Goals/CreditUpdateBalanceSheet.swift` | Same chrome for choice / manual / PIN (11a–11c) |

## Visual summary

| State | Chrome |
|-------|--------|
| Choice (4 / 11a) | Title + helper; white choice rows (Manually / Balance sync) with icon, subtitle, chevron, soft card shadow |
| Manual ₹0 (4a / 11b) | Large navy ₹ field on `PiCard`; `PrimaryCTA` Continue muted / disabled |
| Manual non-zero | Same field; Continue filled navy |
| UPI PIN Demo (4b / 11c) | DEMO chip; bank masked line; navy PIN dots; card mock pad; Check balance primary + Cancel outline |
| Wrong PIN (4d / 4e) | Destructive title + error dots; Try again primary / Enter manually outline |
| Other app (4c) | Primary CTA Enter balance manually |

## Acceptance criteria

- [x] Given Update balance sheet, When shown, Then Manually / Balance sync choice rows match Paytm-like design
- [x] Given Manual amount, When ₹0, Then disabled Continue styling matches design; non-zero enables navy CTA look
- [x] Given UPI PIN Demo, When shown, Then Demo label, bank masked line, mock pad, Check balance / Cancel match design
- [x] States: choice; ₹0 vs amount; wrong PIN visual (no logic change)
- [x] Tests: existing PIN/update tests green; `cd PiPlanner && swift test` all green

## Reviewer checklist

1. Setup Consent No → Update balance: two card choice rows (not system bordered buttons).
2. Manually → ₹0 Continue muted; type amount → navy Continue.
3. Balance sync → DEMO badge, HDFC ••4821 (or dedicated title), pad, Check balance / Cancel.
4. Wrong PIN → red Incorrect PIN + Try again / Enter manually (same navigation as before).
5. Goals Consent Off → Update balance sheet: same choice / manual / PIN chrome (11a–11c).

## References

- PRD R8: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 4, 4a–4e, 11a–11c: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components)

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22). Touched only Update balance / UPI PIN chrome files (+ ticket doc / pbxproj for new chrome helper). Avoided Welcome / Accounts / Consent Yes / Goals home / Sync sheet (PIP-73/75/79/81/83).

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures**.

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

PIN validation / sync behaviour; ViewModel product logic; Consent Yes / Accounts / Welcome restyles; Sync sheet Previous/Fetched/New (PIP-83); Android twin (PIP-78).
