# PIP-63 [iOS] Implement Ask tab with Grok answers and proposals

Ticket: https://linear.app/telco-paytm/issue/PIP-63/ios-implement-ask-tab-with-grok-answers-and-proposals

## Delivered

Ask tab under `PiPlanner/Views/Ask/` with pure `AskService` (Linux-testable), `AskViewModel`, `ProposalCard`, extended `StubGrokService.askQuestion(query:engine:)` for plain answers / action proposals / unavailable / invalid-draft, and sheet wiring to Transfer (16c), Standing split, and Goal form (13f). `MainTabView` passes `accounts` additively (Settings/History untouched).

| Type / file | Role |
|-------------|------|
| `AskService` | Chips, engine-number answers, proposal copy, 19d follow-up policy |
| `AskEngineContext` | Ledger snapshot for 19a numbers (PIP-65-friendly) |
| `StubGrokService` | Deterministic Ask stub: transfer / add goal / change split / plain / errors |
| `AskViewModel` | Phases: input, plainAnswer, proposal, unavailable, invalidDraft |
| `ProposalCard` | Edit / Confirm + “Checked by PiPlanner. Estimate.” |
| `AskTabView` | Chips + input; fallback templates/forms; sheets |
| `MainTabView` | Passes `accounts` into Ask (additive) |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| R18 Ask (19) chips + input | `AskService.suggestionChips` + `AskTabView` composer |
| 19a plain answer engine numbers | `AskService.plainAnswer` via `askQuestion(..., engine:)` |
| 19b proposal Edit/Confirm + checked label | `ProposalCard` + `StubGrokService.checkedByLabel` |
| Confirm → sheet prefilled (13f / 16c) | Transfer / Goal form / Standing split sheets |
| 19c Grok unavailable | Templates + Goal form + Standing split CTAs |
| 19d invalid draft | Ask once more, then Goal form; never show invalid cards |
| Spec §3.3 GrokService | Protocol + stub; no real AI |

## Acceptance criteria

- [x] Given Ask (19), when opened, then chips and input field shown
- [x] Given question with no action, when answered (19a), then plain-text answer uses engine numbers
- [x] Given action sentence, when detected (19b), then proposal card with Edit/Confirm and "Checked by PiPlanner. Estimate." shown
- [x] Given proposal Confirm, when tapped, then matching sheet opens pre-filled (13f, 16c)
- [x] Given Grok unavailable (19c), when detected, then fallback forms/sliders/templates offered
- [x] Given invalid draft (19d), when received, then user asked once more, then Goal form; invalid drafts never shown
- [x] States handled: Input, Plain answer, Proposal, Unavailable, Invalid draft
- [x] Tests: unit tests for GrokService stub responses and fallbacks

## Parallel work / base

Rebased onto `main` @ `e37940b` (PIP-65 Demo seeding after PIP-61 Settings). Additive only — History / Settings / Transfer / Withdrawal / `DemoData` not rewritten. `MainTabView` keeps PIP-65 `onDemoReset` plus Ask `accounts:`. `GrokService` keep-both: PIP-63 `AskEngineContext` answers + PIP-65 `happyPathAskAnswer`.

## How to run tests

```bash
cd PiPlanner
swift test
```

**Result:** 179 tests, 0 failures (includes expanded `GrokServiceTests` + `AskServiceTests`).

## Assumptions

- Design chip copy: “What happens if I change the split?” / “Why is inflation 7%?” (design extract J8).
- Informational questions (what/why/how) never become proposal cards; imperatives become Transfer / Add goal / Change split.
- Invalid-draft stub triggers: empty, `asdf`, `???`, or text containing `invalid draft`.
- Ask 19d allows **one** follow-up then Goal form (stricter than Goal chat’s two).
- Add-goal demo proposal: Vacation ₹50,000 / 20% share (13f).

## Out of scope

Real Grok/AI integration; PIP-65 demo persona seeding; Settings (PIP-61 already on main).
