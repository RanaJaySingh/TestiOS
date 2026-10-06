# PIP-43 [iOS] Implement Opening split screen

Ticket: https://linear.app/telco-paytm/issue/PIP-43/ios-implement-opening-split-screen

## Delivered

Opening split (frames 8 / 8b) under `PiPlanner/Views/Setup` with `OpeningSplitViewModel`, `OpeningSplitService` (BR-2 / BR-3), locked Opening balance History entry creation, navigation to Goals tab placeholder (PIP-45), and unit tests.

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| BR-2 / R22 Splits always total 100% | `OpeningSplitService.isValidHundredPercent` + Lock disabled via `canLock` |
| BR-3 / R6 / R16 Locked opening | `createLockedOpeningEntry` sets `isLocked = true`; read-only caption **"Locked amounts never change"** |
| Frame 8 multi-goal | % fields; running total / shortfall copy |
| Frame 8b single-goal | Auto 100%; no editable % fields |
| History Opening balance | `HistoryEntryType.openingBalance` + allocations; goals `savedAmount` + standing splits updated |
| Navigate to Goals (9) | `OpeningSplitFlowView` → `GoalsTabPlaceholderView` |

## Acceptance criteria

- [x] Multi-goal percentages must sum to 100% to enable Lock
- [x] Single-goal (8b): 100% auto-assigned, no % fields
- [x] Lock confirmed → Opening balance History entry created
- [x] After lock → navigate to Goals tab (placeholder)
- [x] Opening entry viewed later → read-only ("Locked amounts never change")
- [x] States: Multi-goal, Single-goal
- [x] Unit tests: 100% validation; History entry creation

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

Full Goals tab (PIP-45), edit of opening entry after lock, earlier setup screens (Welcome → Goal form).
