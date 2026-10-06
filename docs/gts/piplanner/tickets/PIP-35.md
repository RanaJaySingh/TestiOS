# PIP-35 [iOS] Implement Welcome screen

Ticket: https://linear.app/telco-paytm/issue/PIP-35/ios-implement-welcome-screen

## Delivered

Welcome screen (frame 1) under `PiPlanner/Views/Setup` with three design-matched "How it works" steps, CTA **Set up savings**, root routing for first-run / post–Reset demo via `AppLaunchRouter`, navigation into the existing Accounts screen (PIP-37), XCUITest target + unit tests for routing / ViewModel.

## Mapping to Spec / PRD / Design

| Requirement | Implementation |
|-------------|----------------|
| PRD R1 Welcome + setup entry | `WelcomeView` + `WelcomeFlowView` |
| Design frame 1 steps + CTA | Copy from Design Source extract |
| First-run / post-reset → Welcome | `AppLaunchRouter.destination` when no locked Opening entry |
| CTA → Accounts (2) | `WelcomeRoute.accounts` → existing `AccountsView` |
| Accessibility / Dynamic Type | Labels, identifiers, `.fixedSize` / flexible text |
| UI test Welcome + navigation | `PiPlannerUITests/WelcomeUITests.swift` |

## Acceptance criteria

- [x] First-run / post–Reset → Welcome appears (`AppLaunchRouter` + `-reset-demo` launch arg for UI tests)
- [x] Three "How it works" steps visible
- [x] "Set up savings" → Accounts screen
- [x] States: First-run, Post-reset
- [x] UI test for display + navigation (Xcode); routing unit-tested on Linux via `swift test`

## How to run tests

Linux / SwiftPM (routing + services; no UIKit):

```bash
cd PiPlanner
swift test
```

macOS with Xcode (unit + UI tests):

```bash
cd PiPlanner
xcodebuild -scheme PiPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test
```

UI tests launch with `-reset-demo` so the app always starts on Welcome.

## Notes

- This Linux Cloud Agent host has no Swift/Xcode toolchain; UI tests are authored for Xcode and cannot be executed here.
- Loading state intentionally omitted (not designed / out of scope).
- Setup-complete (locked Opening balance) still routes to Goals placeholder so later screens are not broken.

## Out of scope

Loading UI, Consent sheet (PIP-39), changing Accounts/Opening business logic beyond root entry, merge to main.
