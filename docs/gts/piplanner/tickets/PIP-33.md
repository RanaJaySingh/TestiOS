# PIP-33 [iOS] Set up project with data models and persistence

Ticket: https://linear.app/telco-paytm/issue/PIP-33/ios-set-up-project-with-data-models-and-persistence

## Delivered

SwiftUI Xcode project under `PiPlanner/` with Spec §4.2 folder layout, shared models (§3.1), error/analytics stubs (§3.4–3.5), `PersistenceService` (JSON + Reset demo), and `FormattingService` (INR Indian grouping / R20).

## Mapping to Spec

| Spec | Implementation |
|------|----------------|
| §3.1 Account / Goal / HistoryEntry / StandingSplit | `PiPlanner/Models/*` — money as `Int64` paisa per Decisions Log |
| §3.1 GoalAllocation, HistoryEntryType, GoalStatus | Co-located with HistoryEntry / Goal |
| §3.4–3.5 Errors / AnalyticsEvent | `AppErrors.swift`, `AnalyticsEvent.swift` |
| §4.1 MVVM + local JSON persistence | Scaffold folders + `PersistenceService` actor |
| §4.2 Project structure | `App/`, `Models/`, `Services/`, `ViewModels/`, `Views/`, `Components/`, `Resources/` |
| BR-10 / PRD R20 | `FormattingService.formatINR(paisa:)` → `₹X,XX,XXX` |

## Acceptance criteria

- [x] Xcode SwiftUI app target (`PiPlanner.xcodeproj`) — open on macOS to build
- [x] Models match shared contract (aligned with Android PIP-34)
- [x] Paisa → Indian-grouped ₹ display
- [x] Reset demo clears all persisted JSON state
- [x] Fresh install / post-reset → empty `PersistedAppState`
- [x] Unit tests: INR formatting, Codable round-trips, persistence reset

## How to run tests

```bash
cd PiPlanner
swift test
```

On macOS with Xcode:

```bash
cd PiPlanner
xcodebuild -scheme PiPlanner -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Out of scope (later tickets)

UI screens, BalanceSyncService / GrokService behavior, demo persona seeding, ViewModels.
