# PIP-73 [iOS] Welcome visual parity

Ticket: https://linear.app/telco-paytm/issue/PIP-73/ios-welcome-visual-parity

## Delivered

Restyled Welcome (frame 1) to match design hierarchy using PIP-67 tokens and PIP-69 shared components — **without** ViewModel or setup-navigation behaviour changes.

| Type / file | Role |
|-------------|------|
| `Views/Setup/WelcomeView.swift` | Brand/tagline, numbered How-it-works 1–3 in `PiCard`, navy `PrimaryCTA` “Set up savings”; `DesignTokens` spacing; `PiColors` / `PiTypography`; previews for first-launch & Reset-demo visual states |

## Visual changes (summary)

- App background `PiColors.backgroundApp` + `.piPlannerTheme()` (light + navy tint).
- Brand **PiPlanner** as navy hero (`amountHero`); tagline navy-deep title; supporting subtitle body/secondary.
- **How it works** section title in navy; steps 1–3 inside `PiCard` with light-blue numbered circles and title/caption hierarchy.
- Primary CTA uses shared `PrimaryCTA` (navy fill) with existing `welcome.cta` accessibility id.
- Spacing from `DesignTokens.Space` (12 / 16 / 20 / 28). Copy and navigation callbacks unchanged.

## Acceptance criteria

- [x] Given first-run / Reset demo, When Welcome shows, Then brand/tagline, numbered How-it-works steps 1–3, supporting copy, and navy primary CTA “Set up savings” match design layout/spacing (tokens + components)
- [x] States: first launch; after Reset demo (same Welcome root — dual `#Preview`s)
- [x] Tests: existing Welcome tests unchanged (a11y ids preserved); `cd PiPlanner && swift test` green; prefer previews for visual states

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R6 Welcome visual parity | `WelcomeView` hierarchy + spacing |
| Spec §4.2 J1 Welcome | Frame 1 restyle only |
| Design frame 1 | Brand, How it works 1–3, CTA “Set up savings” |
| PIP-67 / PIP-69 | Tokens + `PiCard` / `PrimaryCTA` |

## Consumption (existing ViewModel — unchanged)

```swift
WelcomeView(viewModel: WelcomeViewModel()) {
    // navigate to Accounts — unchanged
}
```

Accessibility identifiers preserved: `welcome.brand`, `welcome.header`, `welcome.howItWorks`, `welcome.steps`, `welcome.step.1..3`, `welcome.cta`.

## References

- PRD R6: https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §4.2 J1: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design frame 1: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit
- Blocked by: PIP-69 (shared components on main)

## Parallel work / base

From `main` @ `b30a048` (PIP-69 #22 merge; includes tokens PIP-67, Components PIP-69, PiIcons+MainTab PIP-71). Touches **only** Welcome-related view + this ticket doc — rebase-friendly vs PIP-75/77/79/81.

## Test results

`cd PiPlanner && swift test` — **206 tests, 0 failures**. Views excluded from SPM target; Welcome UITests/ViewModelTests remain Xcode-host (a11y ids unchanged).

## How to run tests

```bash
cd PiPlanner
swift test
```

SwiftUI previews: open `WelcomeView` `#Preview("Welcome · first launch")` / `#Preview("Welcome · after Reset demo")` in Xcode.

## Out of scope

Setup navigation/behaviour (PIP-33..66); ViewModel/product-behaviour changes; shared Theme/Components/MainTab edits; Android (PIP-74 twin).
