# PIP-99 [iOS] Accounts + Consent screens

Ticket: https://linear.app/telco-paytm/issue/PIP-99/accounts-consent-screens

## Delivered

Wire Welcome → Accounts → **Consent sheet** (Yes / No) using existing `DesignTokens` / `Pi*` chrome on main. Behavior for dedicated toggle, Consent Yes (auto balance updates + fetch), and Consent No (Update balance next). Spending balances stay visible on Accounts only; ledger mutations go through `LedgerFacade` stub until PIP-98 merges.

| Type / file | Role |
|-------------|------|
| `Views/Setup/WelcomeFlowView.swift` | Consent presented as `.sheet` over Accounts; Yes → Fetched balance; No → Update balance |
| `Views/Setup/AccountsFlowView.swift` | Same Consent sheet wiring for Accounts-only demos |
| `Views/Setup/AccountsView.swift` | Frame 2 — exclusive dedicated toggle + gated Continue (unchanged chrome) |
| `Views/Setup/ConsentSheet.swift` | Frame 3 — `PiSheet` Yes / No (unchanged chrome) |
| `Services/AccountsService.swift` | Role labels + spending-only-on-Accounts helpers |
| `Services/LedgerFacade.swift` | PIP-98 stub — dedicated opening balance / consent decline |
| `ViewModels/AccountsViewModel.swift` | Uses `AccountsService.roleLabel` |
| `ViewModels/ConsentViewModel.swift` | Persists via `LedgerFacade` |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| Welcome → Accounts → Consent | `WelcomeFlowView` navigation + Consent sheet |
| Mark one account dedicated | `AccountsService.applyingDedicatedToggle` + Continue gating |
| Spending shown only on Accounts | `tracksBalanceOutsideAccounts` / Goals uses dedicated only |
| Consent Yes → auto updates | `chooseConsentYes` → `consentAutoUpdate = true` + fetch ₹1,00,000 |
| Consent No → Update balance | Sheet dismiss → `UpdateBalanceSheet` (PIP-100 owns Manual/PIN routes) |
| Ledger until PIP-98 | `LedgerFacade.applySetupOpeningBalance` / `applyConsentDeclined` |
| Visual components | Existing `PiCard` / `PrimaryCTA` / `SecondaryCTA` / `PiSheet` / tokens |

## Acceptance criteria

- [x] Welcome → Accounts → Consent sheet (Yes / No)
- [x] Exactly one dedicated savings; Continue gated
- [x] Spending balance shown on Accounts; not tracked outside Accounts
- [x] Consent Yes → auto balance updates + opening balance fetch (3a)
- [x] Consent No → Update balance choice next
- [x] Ledger calls stubbed cleanly via `LedgerFacade` (PIP-98 not required)
- [x] Uses existing DesignTokens / Pi* components
- [x] `cd PiPlanner && swift test` green

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Update balance Manual / UPI PIN routes (PIP-100); Ledger engine (PIP-98); Goal form / Opening split (PIP-101); Goals Sync (PIP-102); food-delivery; PIP-104..108; merge / Done.

## Test results

`cd PiPlanner && swift test` — **215 tests, 0 failures** (Linux `PiPlannerCore` suite; +4 for `LedgerFacade` / Accounts spending visibility).
