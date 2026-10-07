# PIP-65 [iOS] Implement Demo persona data seeding

Ticket: https://linear.app/telco-paytm/issue/PIP-65/ios-implement-demo-persona-data-seeding

## Delivered

Moved demo persona seeding into `PiPlanner/Services/DemoData.swift` (Linux-testable; `typealias DemoSeed = DemoData` keeps existing call sites). Seeds Rahul with HDFC ••4821 ₹1,00,000 (dedicated after setup) and SBI ••7730 ₹72,000 (spending). Goals tab shows time-of-day greeting (`Good evening, Rahul`). R25 helper ensures spending-account payments produce no History. Grok stub Ask answers extended additively for Car / Emergency Fund (PIP-63-safe). Settings → Reset demo (PIP-61) still reseeds `DemoData.sampleAccounts` via `ContentView.returnToWelcome`.

| Type / file | Role |
|-------------|------|
| `DemoData` / `DemoSeed` | Persona name, accounts, goals, post-setup state, greeting, R25 |
| `ContentView` | First launch / post-reset seed; Reset demo → Welcome + sample accounts |
| `GoalsTabView` / `GoalsViewModel` | Persona greeting header |
| `StubGrokService` | Additive `happyPathAskAnswer` for Car / Emergency queries |
| `DemoDataTests` | Unit coverage for seed init, greeting, R25, reset path |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD §3 / §10 persona | `DemoData.sampleAccounts` / `postSetupAccounts` |
| A8 greeting | `DemoData.greeting(at:)` → Goals `personaGreeting` |
| R25 spending not seen | `tracksPayments` / `historyEntriesForSpendingPayment` → `[]` |
| R5 / A7 Grok happy path | Existing `happyPathProposals` + Ask `happyPathAskAnswer` |
| R17 Reset demo | PIP-61 `resetDemo` + reseed `DemoData.sampleAccounts` |
| Spec §4.2 DemoData | Implemented under `Services/` for `swift test` (PiPlannerCore) |

## Acceptance criteria

- [x] Given app launch, when demo persona available, then Rahul name visible in greeting
- [x] Given demo accounts, when seeded, then HDFC ••4821 ₹1,00,000 (dedicated) and SBI ••7730 ₹72,000 (spending) exist
- [x] Given spending account (SBI), when payments occur, then PiPlanner shows nothing for those payments (R25)
- [x] Given Grok stub, when goal proposals shown, then happy path matches design (Car / Emergency fund)
- [x] Given "Good evening, Rahul" greeting, when time-of-day varies, then greeting adjusts appropriately
- [x] States handled: First launch, Post-reset
- [x] Tests: Unit test for demo data initialization

## Parallel work / base

Started from `main` @ `4458dcc` (PIP-61 Settings). Additive only — Settings reset path kept; Grok Ask table extended without rewriting analyze paths; no History / Transfer / Withdrawal rewrites.

## Test results

`cd PiPlanner && swift test` — **175 tests, 0 failures** (includes 8 `DemoDataTests` + 1 additive Grok Ask happy-path test).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Real backend / auth; full Ask tab UI (PIP-63); Settings UI (PIP-61 already shipped).
