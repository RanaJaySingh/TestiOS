# PIP-79 [iOS] Goal chat, form, inflation, opening split visual

Ticket: https://linear.app/telco-paytm/issue/PIP-79/ios-goal-chat-form-inflation-opening-split-visual

## Delivered

Restyle Goal chat, Goal form, Inflation popup, and Opening split to design cards / proposal treatment / Lock this split CTA — **visual / layout / token / component wiring only**. No ViewModel or product-behaviour changes. Consumes PIP-69 shared components (`ProposalCard`, `PiCard`, `PrimaryCTA`, `SecondaryCTA`, `LightBlueChip`, `PiSheet`) and PIP-67 `DesignTokens` / `PiColors` / `PiTypography`.

| Type / file | Role |
|-------------|------|
| `Views/Setup/GoalChatView.swift` | Bubbles (light-blue user / white assistant), `ProposalCard` (“Grok's proposal”), Use a form link, unavailable + goals-defined `PiCard` / `PrimaryCTA` |
| `Views/Setup/GoalFormView.swift` | Field stack in `PiCard`, valid/invalid chrome, inflation row, live metrics, `PrimaryCTA` Save / `SecondaryCTA` Cancel |
| `Views/Setup/InflationPopup.swift` | `PiSheet` chrome, ± stepper (`LightBlueChip`), live adjusted target, `PrimaryCTA` “Use this rate” |
| `Views/Setup/OpeningSplitView.swift` | Balance + goal rows in `PiCard`, % fields, `PrimaryCTA` “Lock this split” (enabled @ 100%) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R9 proposal card | `ProposalCard(title: "Grok's proposal", …)` + `checkedByLabel` |
| PRD R9 form / inflation / split | Field stack + inflation stepper sheet + Lock CTA |
| Spec §3.5 components | Consume shared Components/ — no second proposal shell |
| Spec §4.2 J1 screens 5–8 | Visual-only restyle of existing setup views |

## Acceptance criteria

- [x] Given Goal chat, When proposal shows, Then “Grok's proposal”, Edit/Confirm, “Checked by PiPlanner. Estimate.”, bubbles, and Use a form link match design
- [x] Given Goal form + Inflation sheet, When rendered, Then field stack, inflation row/stepper, live targets, Use this rate match design
- [x] Given Opening split, When rendered, Then goal rows, %, Lock this split CTA match design
- [x] States: chat idle/proposal; form valid/invalid chrome; split ≠100% vs 100% CTA
- [x] Tests: behaviour tests green; `cd PiPlanner && swift test` all green

## Reviewer checklist

Compare simulator/device to design frames 5, 5a–5c, 6, 7, 8, 8b:

1. Proposal uses shared `ProposalCard` hierarchy (not a forked shell); title is “Grok's proposal”.
2. Chat bubbles: user = light-blue chip fill; assistant = white card surface; app background `#F5F7FB`.
3. “Use a form” is navy text (toolbar / secondary treatment).
4. Form invalid: amber behind stroke + helper; Save `PrimaryCTA` disabled. Valid: clean card + enabled Save.
5. Inflation sheet: PiSheet handle/title; ± stepper; live adjusted ₹; CTA label **Use this rate**.
6. Opening split: navy Lock this split CTA enabled only when % total 100%; disabled (muted) when ≠100%.

## References

- PRD R9: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components)

## Parallel work / base

Started from `b30a048` (main after PIP-69 #22). Touched **only** GoalChat / GoalForm / Inflation / OpeningSplit view files + this ticket doc. Prefer existing `Components/ProposalCard` — no second proposal shell.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures** (Views excluded from Linux SPM; behaviour suites unchanged).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Grok stub / validation / lock logic (Done); ViewModel behaviour; Android twin (PIP-80); Goals home / Ask / other screen tickets.
