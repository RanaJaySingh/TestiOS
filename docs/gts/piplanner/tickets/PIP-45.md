# PIP-45 [iOS] Implement Goals tab with balance card and goal cards

Ticket: https://linear.app/telco-paytm/issue/PIP-45/ios-implement-goals-tab-with-balance-card-and-goal-cards

## Delivered

Goals tab + main tab bar under `PiPlanner/Views` with `GoalsViewModel`, pure `GoalsTabService` (Linux-testable), `BalanceCard` / `GoalCard`, stubs for `SyncSheet`, `GoalsUpdateBalanceSheet`, `GoalDetailView`, `HistoryTabView`, `AskTabView`, `SettingsView`, and wiring that replaces `GoalsTabPlaceholderView` after Opening lock / post-setup launch.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| Spec §4.3 Tab bar Goals \| History \| Ask | `MainTabView` — no Settings tab |
| Frame 9 balance card + INR | `BalanceCard` + `FormattingService` via `GoalsViewModel.formattedTotalSavings` |
| Frame 9 / 11 goal cards + status | `GoalCard` + `GoalsTabService.statusLabel` (On track / Behind) |
| Goal card → detail | `NavigationLink` → `GoalDetailView` (minimal stub) |
| Consent On → Sync (9b) | `GoalsTabService.balanceAction` → `.sync` → `SyncSheet` + `BalanceSyncService` |
| Consent Off → Update balance (9c) | `.updateBalance` → `GoalsUpdateBalanceSheet` (setup frame 4 keeps existing `UpdateBalanceSheet`) |
| Gear → Settings | Toolbar gear → `SettingsView` stub |
| R21 dedicated account total | Prefer dedicated `Account.balance`; fallback sum of `Goal.savedAmount` |
| Post-setup launch | `ContentView` / Welcome / Accounts / OpeningSplit → `MainTabView` |

## Acceptance criteria

- [x] Balance card shows total savings with INR formatting (₹ + Indian grouping)
- [x] Each goal shows as a card with saved amount and status (On track / Behind)
- [x] Goal card tap → navigates to Goal detail (`GoalDetailView` stub)
- [x] Consent On → Sync button; tapping presents SyncSheet / calls BalanceSyncService stub
- [x] Consent Off → Update balance; tapping presents GoalsUpdateBalanceSheet stub
- [x] Goals header gear → opens Settings (`SettingsView` stub)
- [x] States: Post-setup, With goals, Consent On/Off
- [x] Tests: `GoalsTabServiceTests` (Linux), `GoalsViewModelTests` (Xcode), `GoalsTabUITests` (macOS XCUITest soft skip without fixture)

## How to run tests

```bash
cd PiPlanner
swift test
```

On macOS with Xcode (includes ViewModel + UI tests):

```bash
cd PiPlanner
xcodebuild -scheme PiPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Assumptions

- Total savings uses dedicated account balance when present (PRD R21); otherwise sums goal `savedAmount`.
- Goals-tab Update balance stub is named `GoalsUpdateBalanceSheet` to avoid clashing with setup frame 4 `UpdateBalanceSheet` in `ConsentSheet.swift`. File path remains `Views/Goals/UpdateBalanceSheet.swift` per Spec §4.2.
- Sync / Update only refresh dedicated balance; full credit-entry locking is out of scope.
- History / Ask / Settings / Goal detail are intentional stubs for later tickets.
- Header chrome (Search / notifications / bar_chart) omitted per R27 / ticket Out scope.
- Design artifact frames 9/9b/9c/11 were not scraped; copy follows Spec §4.3 + ticket AC.

## Out of scope

Header chrome (R27); full Goal detail CRUD; Standing split; Delete; Transfer; Withdrawal; full credit-entry locking; real bank sync.
