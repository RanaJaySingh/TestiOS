# PIP-55 [iOS] Implement Transfer between goals

Ticket: https://linear.app/telco-paytm/issue/PIP-55/ios-implement-transfer-between-goals

## Delivered

Transfer flow under `PiPlanner/Views/Goals/TransferView.swift` (+ `TransferFlow` entry), `TransferViewModel`, pure `TransferService`, locked History `transfer` entry (“From → To · amount”), standing split left unchanged (BR-7), amount chips ₹1,000 / ₹5,000 / ₹10,000, after-transfer preview, over-amount Move disable (16b), Ask proposal prefill (16c). Goal detail Transfer + Goals tab Transfer entry + Ask “Open Transfer” wire to the real flow (replaces `GoalTransferStubView`).

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R14 / BR-7 Transfer does not change standing split | `TransferService.applyTransfer` snapshots + restores `standingSplits` / `shareOfNewCredits` |
| Frames 16 From/To/amount/chips/preview/Move | `TransferView` + `TransferViewModel` |
| 16b over-amount disables Move | `isOverAmount` / `canMove` / phase `.overAmount` |
| 16a History From → To · amount | Locked `HistoryEntryType.transfer`; `TransferService.historyTitle` |
| 16c Ask prefill | `StubGrokService.askQuestion` → `ProposedAction.transfer` → `TransferService.Prefill` via Ask tab |
| States Select / Enter amount / Preview / Over-amount / Complete | `TransferService.Phase` |
| Paisa storage | UI rupees → `parseAmountPaisa` / `paisa(fromRupees:)` |

## Acceptance criteria

- [x] Given Transfer (16), when opened, then From/To selectors and amount field shown
- [x] Given amount, when chips (₹1,000 / ₹5,000 / ₹10,000) tapped, then amount auto-filled
- [x] Given After transfer preview, when shown, then new balances displayed
- [x] Given amount > From saved (16b), when entered, then Move button disabled
- [x] Given valid transfer, when Move tapped, then money moves and History entry (16a) created
- [x] Given standing split, when transfer completes, then it remains unchanged
- [x] Given Ask proposal (16c), when received, then Transfer opens pre-filled
- [x] States handled: Select, Enter amount, Preview, Over-amount, Complete
- [x] Tests: Unit test for validation and History entry

## Parallel work / base

Started from `main` @ `a6c318e` (PIP-53 Delete goal). Additive only: no StandingSplit / Credit* / DeleteGoal* / Withdrawal rewrites.

- Goal detail Transfer destination → `TransferFlow` (minimal change; stub removed).
- Goals tab leading “Transfer” NavigationLink when ≥2 goals.
- Ask tab minimal proposal card opens Transfer sheet with prefill (full Ask remains PIP-63).
- `project.pbxproj`: TransferService / ViewModel / View / Tests entries.

## How to run tests

```bash
cd PiPlanner
swift test
```

## Round-1 review must-fix

**Issue:** After Complete, `canMove` ignored `didComplete`, so Move stayed enabled on Goals/Detail (no dismiss) and a second tap could transfer again / write another History entry.

**Fix:** `TransferService.canMove(..., isComplete:)` returns false when complete; `TransferViewModel.canMove` passes `didComplete`; `confirmMove()` early-returns when `didComplete`. Regression: `testSuccessfulMoveThenCompleteDisablesSecondMove` + `TransferViewModelTests.testConfirmMoveTwiceDoesNotWriteSecondHistoryEntry`.

## Assumptions

- History presentation string for transfers is `"{From} → {To} · {₹amount}"` (`TransferService.historyTitle`); type label remains “Transfer”.
- Ask stub returns a Transfer proposal when the query contains “transfer” or “move”; demo IDs match Car / Emergency Fund seed UUIDs with ₹5,000.
- Design frames 16 / 16a–16c inferred from PRD R14 + Spec BR-7 (artifact not scraped in-agent).
- Complete is terminal until the user changes From/To/amount (those intents clear `didComplete`).

## Out of scope

Standing split edits; Withdrawal (PIP-57); full Ask tab (PIP-63); History tab list UI.
