# PIP-37 [iOS] Implement Accounts screen with dedicated toggle

Ticket: https://linear.app/telco-paytm/issue/PIP-37/ios-implement-accounts-screen-with-dedicated-toggle

## Delivered

Accounts screen (frame 2) under `PiPlanner/Views/Setup` with `AccountsViewModel`, `AccountsService` (BR-1 exclusive dedicated toggle + Continue gating), navigation to Consent placeholder (PIP-39), demo HDFC ••4821 / SBI ••7730 seed, and unit tests.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| BR-1 / R2 Exactly one dedicated | `AccountsService.applyingDedicatedToggle` + `canContinue` |
| R21 One dedicated ongoing rule | Setup requires exactly one dedicated before Consent |
| Frame 2 / Step 1 of 3 | `AccountsView` header + exclusive Dedicated toggles |
| Continue gated | Disabled when none dedicated; enabled with exactly one |
| Navigate to Consent (3) | `AccountsFlowView` → `ConsentPlaceholderView` |
| Demo accounts | `DemoSeed.sampleAccounts` — HDFC ••4821, SBI ••7730 |

## Acceptance criteria

- [x] Toggle Dedicated on one → other turns off
- [x] Continue disabled when none dedicated
- [x] Continue with exactly one → navigate to Consent
- [x] States: None dedicated, One dedicated
- [x] Unit tests: toggle exclusivity + Continue gating

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

## Out of scope

Add/remove accounts UI, full Consent sheet (PIP-39), Welcome screen, Opening split changes.
