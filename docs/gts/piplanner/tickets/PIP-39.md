# PIP-39 [iOS] Implement Consent sheet and balance entry flows

Ticket: https://linear.app/telco-paytm/issue/PIP-39/ios-implement-consent-sheet-and-balance-entry-flows

## Delivered

Consent Yes/No + balance entry under `PiPlanner/Views/Setup` with `ConsentViewModel`, mock `BalanceSyncService` (Spec §3.3), Manual amount / Demo UPI PIN / other-app / wrong-PIN states, wiring from `WelcomeFlowView` (replacing `ConsentPlaceholderView`), handoff of resolved opening balance into `OpeningSplitView`, and unit tests.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R3 Consent Yes → ₹1,00,000 (3a) | `ConsentViewModel.chooseConsentYes` → `MockBalanceSyncService.fetchBalance` → `FetchedBalanceView` |
| R4 Consent No → Update balance (4) | `chooseConsentNo` → `UpdateBalanceSheet` (Manually / Balance sync) |
| Manual ₹0 disables Continue (4a) | `ConsentService.canContinueManual` + `ManualBalanceView` |
| UPI PIN Demo `"1234"` success (4b) | `MockBalanceSyncService.verifyUPIPin` → fetched balance |
| Wrong PIN → retry/manual (4d/4e) | `WrongPinView` |
| Other UPI app → force manual (4c) | `OtherAppView` via “Account on another UPI app” |
| Spec §3.3 BalanceSyncService | `BalanceSyncService.swift` (mock; paisa `Int64`) |
| Wire Welcome → Consent | `WelcomeFlowView` routes; placeholder removed |

## Acceptance criteria

- [x] Consent Yes → balance ₹1,00,000 shown (3a)
- [x] Consent No → Update balance sheet (4)
- [x] Manual path: amount ₹0 → Continue disabled
- [x] UPI PIN Demo: PIN `"1234"` → balance fetch success
- [x] Wrong PIN → error with retry/manual options (4d, 4e)
- [x] “Account on another UPI app” (4c) → force manual entry
- [x] States: Yes path, No path, Manual, PIN success, PIN fail, Other app
- [x] Unit tests for mock BalanceSyncService

## How to run tests

```bash
cd PiPlanner
swift test
```

On macOS with Xcode (includes ViewModel tests):

```bash
cd PiPlanner
xcodebuild -scheme PiPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Assumptions

- Goal chat (frame 5) is not built yet; after a resolved balance the flow hands off to existing Opening split with `DemoSeed.sampleGoals` and the resolved paisa amount.
- Money remains **Int64 paisa** (Spec Decisions Log); mock Yes/PIN success returns `10_000_000` paisa.
- Design artifact copy was inferred from PRD R3/R4 + screen inventory when the Claude artifact page did not expose frame text.

## Out of scope

Real UPI / bank integration; Goal chat / form changes; Opening split logic beyond receiving a resolved balance.
