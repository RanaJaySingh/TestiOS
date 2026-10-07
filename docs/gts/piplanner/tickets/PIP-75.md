# PIP-75 [iOS] Accounts + Consent + opening balance visual

Ticket: https://linear.app/telco-paytm/issue/PIP-75/ios-accounts-consent-opening-balance-visual

## Delivered

Restyle setup Accounts (frame 2), Consent sheet (frame 3), and Opening balance fetched (frame 3a) to design structure and Paytm-like sheet chrome — **visual / layout / token / component wiring only**. Toggle exclusivity and consent logic unchanged (already Done).

| Type / file | Role |
|-------------|------|
| `Views/Setup/AccountsView.swift` | Step 1 of 3, `PiCard` account rows + navy toggles, gated `PrimaryCTA` Continue, `PiColors.backgroundApp` |
| `Views/Setup/ConsentSheet.swift` (`ConsentSheet`) | `PiSheet` chrome; four navy check bullets; Yes `PrimaryCTA` / No `SecondaryCTA` outline |
| `Views/Setup/ConsentSheet.swift` (`FetchedBalanceView`) | Step 2 of 3; large `PiTypography.amountHero()` ₹ amount in `PiCard`; `PrimaryCTA` Continue |

Frame 4 / 4c / 4d–4e views in the same Consent file (`UpdateBalanceSheet`, `OtherAppView`, `WrongPinView`) are **not** restyled here — owned by PIP-77.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R7 Accounts (2) | Step indicator + account cards/toggles + Continue gated chrome |
| PRD R7 Consent (3) | Sheet chrome over context; four check bullets; Yes / No buttons |
| PRD R7 Opening balance (3a) | Step 2 of 3 + large ₹1,00,000 treatment (`amountHero` + navy) |
| Spec §3.5 / PIP-69 | Consumes `PiCard`, `PrimaryCTA`, `SecondaryCTA`, `PiSheet` + `DesignTokens` / `PiColors` / `PiTypography` |
| Spec §4.2 J1 Setup | Screens 2, 3, 3a only |

## Acceptance criteria

- [x] Given setup Accounts, When shown, Then step indicator, account cards/toggles, and Continue gated chrome match design
- [x] Given Consent, When presented, Then sheet over context with four check bullets and Yes/No buttons match design
- [x] Given Opening balance fetched (3a), When shown, Then Step 2 of 3 and large ₹1,00,000 treatment match design
- [x] States: Continue disabled/enabled; Consent Yes/No visual
- [x] Tests: behaviour tests green; SwiftUI previews for key states; `cd PiPlanner && swift test` green

## Reviewer checklist (frames 2 / 3 / 3a)

Compare simulator/device (or Xcode previews) to design artifact:

1. **Accounts (2):** “Step 1 of 3” caption (navy); white account cards radius 22; dedicated toggles navy tint; Continue uses navy `PrimaryCTA` — disabled until exactly one dedicated, enabled when one is on.
2. **Consent (3):** Paytm-like sheet chrome (handle, title “Allow balance checks?”, helper); four checkmark bullets; Yes filled navy / No outline secondary.
3. **Fetched (3a):** “Step 2 of 3”; large navy ₹ amount (Indian grouping, e.g. ₹1,00,000); Continue primary CTA.
4. No ViewModel / toggle-exclusivity / consent-fetch behaviour changes.

## Previews

- `AccountsView` — None dedicated · Continue disabled; One dedicated · Continue enabled
- `ConsentSheet` — Consent · Yes / No; Consent · Settings 20b
- `FetchedBalanceView` — Fetched balance 3a · ₹1,00,000

## References

- PRD R7: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 2, 3, 3a: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components on main)

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22). Touches only Accounts / Consent / FetchedBalance view files (+ this GTS doc). Avoids Theme/, Components/, MainTab (PIP-73/77/79/81 parallel).

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures** (Linux `PiPlannerCore` suite; Views are Xcode-target-only, same as PIP-69).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Toggle exclusivity / consent logic; ViewModel / money behaviour; Update balance / UPI chrome (PIP-77); Welcome (PIP-73); Goal chat/split (PIP-79); Goals home (PIP-81); Android twin (PIP-76).
