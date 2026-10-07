# PIP-69 [iOS] Shared visual components (Card, CTA, Chip, Sheet, Proposal)

Ticket: https://linear.app/telco-paytm/issue/PIP-69/ios-shared-visual-components-card-cta-chip-sheet-proposal

## Delivered

Reusable SwiftUI visual components under `PiPlanner/Components/`, consuming PIP-67 `DesignTokens` / `PiColors` / `PiTypography` / `piPlannerTheme()`. Visual / layout / token / component only — no ViewModel or product-behaviour changes. Screen wiring deferred to later visual-parity tickets.

| Type / file | Role |
|-------------|------|
| `Components/PiCard.swift` | White surface, `Radius.card` 22, soft single-layer shadow |
| `Components/PrimaryCTA.swift` | Filled navy primary button; enabled / disabled |
| `Components/SecondaryCTA.swift` | Outline or text secondary CTA |
| `Components/LightBlueChip.swift` | Soft light-blue chip; selected / unselected |
| `Components/PiSheet.swift` | Paytm-like sheet chrome (top radius, handle, title spacing) + `.piSheetChrome` |
| `Components/ProposalCard.swift` | Shared proposal shell (moved/refined from Ask PIP-63) — title / Edit / Confirm / footer caption |
| `Components/ComponentsCatalog.swift` | Preview catalog for AC states |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R2 card surface / soft shadow | `PiCard` → `PiColors.surfaceCard` + `DesignTokens.Radius.card` |
| PRD §9 / Spec §3.5 PrimaryButton | `PrimaryCTA` → `PiColors.navyPrimary` |
| PRD §9 / Spec §3.5 SecondaryButton | `SecondaryCTA` outline / text |
| Spec §3.5 LightBlueChip | `LightBlueChip` → chip tokens |
| Spec §3.5 PiSheet | `PiSheet` / `.piSheetChrome(title:helper:)` |
| Spec §3.5 ProposalCard | Shared shell; Ask accessibility ids preserved |
| Spec §4.1 Components/ | Files under `PiPlanner/Components/` (SPM-excluded like Views) |

## Acceptance criteria

- [x] PiCard: white surface + corner radius 20–24 (`DesignTokens.Radius.card` = 22) + soft shadow (not heavy multi-layer)
- [x] Previews / catalog: navy primary, outline/text secondary, light-blue chip, sheet top radius/title spacing, ProposalCard hierarchy
- [x] States: enabled/disabled primary CTA; chip selected/unselected
- [x] Tests: SwiftUI previews + catalog; no ViewModel behaviour changes; `cd PiPlanner && swift test` green

## Consumption API

```swift
// Card
PiCard {
    Text("…").font(PiTypography.body())
}

// CTAs
PrimaryCTA(title: "Set up savings", isEnabled: true) { … }
PrimaryCTA(title: "Continue", isEnabled: false) { … }
SecondaryCTA(title: "Cancel", style: .outline) { … }
SecondaryCTA(title: "Use a form", style: .text) { … }

// Chip
LightBlueChip(title: "₹5,000", isSelected: true) { … }

// Sheet chrome (wrap sheet content; keep SwiftUI .sheet)
PiSheet(title: "Consent", helper: "…") {
    // rows + CTAs
}
// or
content.piSheetChrome(title: "Consent", helper: "…")

// Proposal (same callbacks as PIP-63 Ask)
ProposalCard(
    title: "Grok's proposal",
    summary: "…",
    checkedByLabel: "Checked by PiPlanner. Estimate.",
    onEdit: { … },
    onConfirm: { … }
)
```

Do **not** redefine hex colours — use `PiColors` / `DesignTokens` from `Theme/`.

## References

- PRD R2, §9 component inventory: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §3.5, §4.1: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-67 (tokens on main)

## Parallel work / base

Originally from `main` @ `141a2bc` (PIP-67 #20). Rebased onto `main` @ `22cf8ef` (PIP-71 #21 icon catalog + MainTab chrome). Keep-both on `project.pbxproj`: PIP-69 Components + PIP-71 `PiIcons` / tests. Ask `ProposalCard` moved into `Components/` with identical accessibility identifiers and callback API.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures** (post PIP-71 rebase; includes 4 `ComponentsContractTests` + PIP-71 `PiIconsTests` + `DesignTokensTests`).

## How to run tests

```bash
cd PiPlanner
swift test
```

SwiftUI previews: open `ComponentsCatalog` or individual component `#Preview`s in Xcode.

## Out of scope

Wiring every screen (PIP-73+); behaviour/logic from PIP-33..66; ViewModel changes; Android (PIP-70 twin).
