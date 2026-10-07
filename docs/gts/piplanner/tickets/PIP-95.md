# PIP-95 [iOS] Ask tab visual parity

Ticket: https://linear.app/telco-paytm/issue/PIP-95/ios-ask-tab-visual-parity

## Delivered

Ask tab idle / answer / proposal / unavailable chrome restyled to DesignTokens + shared Components — **visual only**. No ViewModel, AskService, or Grok stub behaviour changes. Consumes existing `ProposalCard` (no fork).

| Surface | Visual wiring |
|---------|----------------|
| Idle header | Intro copy via `PiTypography` + `AskService.headerCaption` |
| Suggestion chips | `LightBlueChip` (soft light-blue fill / navy label) |
| Ask Grok input | White field, chip radius, navy stroke; `PrimaryCTA` Ask |
| Plain answer (19a) | `PiCard` answer hierarchy |
| Proposal (19b) | Shared `Components/ProposalCard` Edit / Confirm + footer |
| Unavailable (19c) | `PiCard` + template `LightBlueChip`s + Primary/Secondary CTAs |
| Invalid draft (19d) | Outline `SecondaryCTA` → Goal form (chrome only) |
| Screen chrome | `PiColors.backgroundApp` |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R17 Ask idle | Intro + light-blue chips + Ask Grok input |
| PRD R17 / Spec §4.2 J8 answer | `PiCard` for plain answer |
| PRD R17 / Spec §3.5 ProposalCard | Existing `ProposalCard` (PIP-69) |
| Spec §3.5 LightBlueChip / PrimaryButton | Chips + Ask CTA |
| R18 no invented chrome | No badges / promo stickers |

## Acceptance criteria

- [x] Given Ask idle, When shown, Then intro copy, light-blue suggestion chips, Ask Grok input match design
- [x] Given plain answer, When shown, Then answer card hierarchy matches design
- [x] Given proposal, When shown, Then ProposalCard Edit/Confirm + footer match design
- [x] States: idle / answer / proposal / unavailable chrome (visual only)
- [x] Tests: Ask behaviour tests green; `cd PiPlanner && swift test` all green

## Reviewer checklist (AskTabView)

Compare simulator/device to design frames 19, 19a–19d:

1. Idle: caption under Ask; soft light-blue suggestion chips; “Ask Grok” field + navy Ask CTA.
2. Plain answer: white `PiCard` (radius 22, soft shadow) for answer body.
3. Proposal: shared ProposalCard — title, summary, “Checked by PiPlanner. Estimate.”, Edit outline + Confirm navy.
4. Unavailable: card with template chips + Use Goal form / Standing split CTAs; no composer/chips row.
5. Background is app light (`#F5F7FB`); no purple / bright `#006BE8` accent on chips/CTAs.

## Parallel work / base

Started from `b30a048` (PIP-69 ProposalCard + PIP-71 icons). Touch **only** `AskTabView` (+ Ask-local chip helper) and this ticket doc. Do not redefine `Components/ProposalCard` API.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures** (AskService / Grok Ask behaviour unchanged).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Grok stub / confirm routing (Done PIP-63); ViewModel / product-behaviour changes; forking a second proposal shell; Android twin (PIP-96).
