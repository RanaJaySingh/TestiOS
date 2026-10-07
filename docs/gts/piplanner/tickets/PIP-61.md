# PIP-61 [iOS] Implement Settings screen

Ticket: https://linear.app/telco-paytm/issue/PIP-61/ios-implement-settings-screen

## Delivered

Settings (frames 20 / 20a / 20b / 20c) under `PiPlanner/Views/Settings/SettingsView.swift` with `SettingsViewModel`, pure `SettingsService` (Linux-testable), Linked accounts list, Automatic balance updates toggle, Consent sheet re-open when turning On (20b), Reset demo confirmation → Welcome (1), Standing split entry retained (PIP-51). Goals gear remains the only entry (no Settings tab — A4). Consent drives Goals **Sync** vs **Update balance** via existing `GoalsTabService.balanceAction`.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R17 Settings via Goals gear (20) | `GoalsTabView` gear → `SettingsView` sheet |
| Linked accounts | Settings section listing dedicated + spending |
| Automatic balance updates On → Sync | `consentAutoUpdate` on dedicated `Account`; `GoalsTabService.balanceAction` → `.sync` |
| Off (20a) → Update balance | Persist `consentAutoUpdate = false`; Goals shows Update balance |
| Off→On (20b) → Consent sheet | `shouldReopenConsent` + `ConsentSheet(showsSetupStep: false, fetchesBalanceOnYes: false)` |
| Untyped gap while Off (20c) | Hint copy in Settings Off; next Sync creates one untyped credit (existing Credit Sync) |
| Reset demo → Welcome (1) | `persistence.resetDemo()` + `ContentView.returnToWelcome` |
| Spec §3.1 Account.consentAutoUpdate | `SettingsService.applyingConsent` |
| Spec §4.3 no Settings tab | Gear only; MainTab unchanged (Goals \| History \| Ask) |

## Acceptance criteria

- [x] Given Settings (20), when opened via Goals gear, then Linked accounts and Automatic balance updates visible
- [x] Given consent On, when Sync available on Goals, then automatic balance check works
- [x] Given consent Off (20a), when Update balance shown on Goals, then manual entry required
- [x] Given consent Off, when turned On (20b), then Consent sheet re-opens
- [x] Given untyped gap while Off (20c), when On synced later, then arrives as one amount
- [x] Given Reset demo, when tapped, then goals/history cleared and Welcome (1) shown
- [x] States handled: Consent On, Consent Off, Reset confirmation
- [x] Tests: Unit test for consent state persistence and reset

## Parallel work / base

Started from `main` @ `3f91f3d` (PIP-55 Transfer). Additive only:

- `SettingsView` expanded (kept Standing split navigation).
- `ConsentSheet` optional `showsSetupStep` / `fetchesBalanceOnYes` for Settings reuse.
- `ContentView` / `MainTabView` / `GoalsTabView` gain optional `onDemoReset` callback.
- No Transfer / Withdrawal / DeleteGoal / Credit* rewrites; MainTab tab list untouched for PIP-59 History.

## Test results

`cd PiPlanner && swift test` — **156 tests, 0 failures** (includes 8 `SettingsServiceTests` for consent persistence + reset → Welcome). `SettingsViewModelTests` excluded from Linux SPM like other VM suites (Xcode host).

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

- Settings Consent Yes (20b) enables auto-update **without** re-fetching / overwriting the stored dedicated balance (setup Yes still fetches opening balance).
- Untyped-gap (20c) copy is shown while Off; the “one amount” behaviour is the existing Sync delta → single `isTyped: false` New credit.
- Reset confirmation uses a destructive alert; successful reset dismisses Settings and replaces the root with Welcome.
- Design frames 20 / 20a–20c inferred from PRD R17 + Design Source extract (artifact not scraped in-agent).

## Out of scope

Separate Settings tab; rewriting Standing split / Credit Sync/Update / Transfer / Withdrawal / DeleteGoal; History tab UI (PIP-59).
