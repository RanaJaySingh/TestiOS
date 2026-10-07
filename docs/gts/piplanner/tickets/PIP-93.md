# PIP-93 [iOS] Settings visual parity

Ticket: https://linear.app/telco-paytm/issue/PIP-93/ios-settings-visual-parity

## Delivered

Restyled Settings (gear from Goals — frames 20 / 20a–20c) under `PiPlanner/Views/Settings/SettingsView.swift` to design grouping using PIP-67 tokens and PIP-69 components. Visual / layout only — no ViewModel, SettingsService, or consent/reset behaviour changes. Settings remains gear entry only (not a fourth tab).

| Surface | Visual treatment |
|---------|------------------|
| Screen chrome | `PiColors.backgroundApp` + `piPlannerTheme()`; ScrollView (not system `List`) |
| Linked accounts | Section header + `PiCard` rows (role navy caption, title, ₹, Paytm link line) |
| Automatic balance updates | `PiCard` + navy-tinted `Toggle`; On/Off chip (light-blue when On); On/Off subtitle + Off untyped-gap hint |
| Standing split | Existing entry kept; card + chevron (PIP-51 behaviour unchanged) |
| Reset demo | Destructive label in `PiCard` under Demo group |
| Reset confirm | `PiSheet` chrome + destructive confirm + `SecondaryCTA` Cancel (replaces system alert chrome only) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R16 Settings visual parity | Grouped Linked accounts · Automatic balance updates · Reset demo |
| Tech Spec §4.2 J7 | Frames 20 / 20a–20c visual must-match |
| PRD R5 / A6 — not a fourth tab | Gear entry unchanged; MainTab untouched |
| Design tokens / components | `DesignTokens`, `PiColors`, `PiTypography`, `PiCard`, `PiSheet`, `SecondaryCTA` |
| Consent On (20) / Off (20a) | Toggle tint + On/Off chip + existing subtitle copy |
| Untyped gap (20c) | Hint remains while Off (`settings.untypedGapHint`) |
| Reset confirm chrome | `PiSheet` sheet; same `showResetConfirmation` / `confirmResetDemo` wiring |

## Acceptance criteria

- [x] Given Settings via Goals gear, When opened, Then Linked accounts, Automatic balance updates copy/toggle, and Reset demo match design grouping (not a fourth tab)
- [x] States handled: consent toggle On/Off visual; Reset confirm chrome
- [x] Tests: Settings tests green; `cd PiPlanner && swift test` all green
- [x] Out: Consent/reset behaviour; ViewModel / product-behaviour changes

## Reviewer checklist (Settings)

Compare simulator/device to design artifact frames 20 / 20a–20c:

1. Entry is Goals gear only — Settings is not a tab.
2. App background is light (`#F5F7FB`); sections are white cards radius 22 with soft shadow.
3. Linked accounts: dedicated first, role / bank / ₹ / “Linked in Paytm” hierarchy.
4. Automatic balance updates: navy toggle; **On** chip + Sync subtitle; **Off** chip + Update-balance subtitle + untyped-gap hint.
5. Reset demo is destructive-styled; confirm uses Paytm-like sheet (title, helper, Reset / Cancel) — not a plain system alert.
6. Done dismisses; Standing split still navigates when goals exist.

## Accessibility ids (unchanged / additive)

| Id | Role |
|----|------|
| `settings.view` | Root |
| `settings.account.<uuid>` | Linked account row |
| `settings.consentToggle` | Toggle |
| `settings.untypedGapHint` | Off-state hint |
| `settings.standingSplit` | Standing split link |
| `settings.resetDemo` | Reset demo button |
| `settings.consentSheet` | Consent re-open (20b) |
| `settings.resetConfirm` | Reset confirm sheet (new chrome) |
| `settings.resetConfirm.confirm` / `.cancel` | Confirm actions |

## Parallel work / base

Started from `b30a048` (PIP-69 Components on main). **Touch only** `SettingsView.swift` (+ this ticket doc) so parallel PIP-73..95 visual tickets rebase cleanly. No Theme / Components / ViewModel / MainTab edits.

## Test results

`cd PiPlanner && swift test` — see PR / CI for count; SettingsService tests unchanged (behaviour Out of scope).

## How to run tests

```bash
cd PiPlanner
swift test
```

SwiftUI previews: `Settings · consent On` / `Settings · consent Off` in `SettingsView.swift`.

## Out of scope

ConsentSheet / Reset demo product behaviour (PIP-61 Done); ViewModel changes; Standing split sheet visual (PIP-89); Android twin (PIP-94); inventing Settings tab or extra chrome (R18).

## References

- PRD R16: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2 J7: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frames 20, 20a–20c: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components)
- Related: PIP-94 (Android twin)
