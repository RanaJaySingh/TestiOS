# PIP-67 [iOS] Design tokens & theme (navy, radii, typography, spacing)

Ticket: https://linear.app/telco-paytm/issue/PIP-67/ios-design-tokens-and-theme-navy-radii-typography-spacing

## Delivered

Shared design-token module under `PiPlanner/Theme/` so later visual tickets (PIP-69+) consume navy, light-blue chips, positive green, behind/destructive, white cards, app background, radii, spacing, and type sizes — **without** screen restyles or product-behaviour changes.

| Type / file | Role |
|-------------|------|
| `Theme/DesignTokens.swift` | One module: `Navy.primary` / `Navy.deep`, chip, status, surfaces, `Radius` (card 22), `Space` 8–28, `TypeSize` |
| `Theme/Color+DesignTokens.swift` | SwiftUI `PiColors` / `PiTypography` (Xcode app target) |
| `Theme/Theme.swift` | `PiTheme` + `View.piPlannerTheme()` — light + navy tint |
| `Assets.xcassets/AccentColor` | `#0A2A6B` (was bright `#006BE8`) |
| `App/PiPlannerApp.swift` | Applies `.piPlannerTheme()` at root |
| `DesignTokensTests` | Token smoke/unit coverage |

## Mapping to Spec / PRD

| Requirement | Implementation |
|-------------|----------------|
| PRD R1 Colour tokens | `DesignTokens.Navy` / `Chip` / `Status` / `Surface` |
| PRD R2 Card radius 20–24 | `DesignTokens.Radius.card = 22` |
| Tech Spec §3.1 tokens | Hex + radius + space 8/12/16/20/24/28 + type sizes |
| Tech Spec §4.1 iOS placement | `Theme/` + AccentColor → navy; light appearance |
| Spec §6.2 token smoke | `DesignTokensTests` |

## Acceptance criteria

- [x] Given approved navy `#0A2A6B`–`#003A8C`, when tokens defined, then `navy.primary`, `navy.deep`, light-blue chip, positive green, behind/destructive, white card, app background exist in one module (no purple/generic substitution)
- [x] Card radius in 20–24 (22); spacing scale 8/12/16/20/24/28 documented in code
- [x] Light appearance only; AccentColor / primary tint → navy
- [x] Token smoke/unit tests; existing behaviour tests remain green

## References

- PRD (R1, R2): https://docs.google.com/document/d/18r0wSKMTpePcjCRYypcKbtabghuCyd_TPGWhLEee0AU/edit
- Tech Spec §3.1 / §4.1: https://docs.google.com/document/d/1pvhxAPCyLrLIzEBNkiUh5-lOA8y7onLiTgl_eJTnlhk/edit
- Design: https://claude.ai/artifact/VtHM2P9uhkH8o8o2kqFHE5
- Design note: https://docs.google.com/document/d/1Gk4Y77wpibYVTeysdDCK4zVY38t7tI9Q35FEbdZlt_U/edit
- Tracker: https://docs.google.com/spreadsheets/d/1ybQaMoz4FWHJoZ_5dXjKISegefE_6PyqmMZ9kX2bnSg/edit

## How to consume (later tickets)

```swift
// Colours (SwiftUI)
PiColors.navyPrimary
PiColors.chipLightBlue
PiColors.positiveGreen
PiColors.surfaceCard

// Layout
RoundedRectangle(cornerRadius: DesignTokens.Radius.card)
.padding(DesignTokens.Space.s16)

// Type
Text("…").font(PiTypography.amountHero())
```

Do **not** restyle screens in this ticket — PIP-69+ owns component/screen visual parity.

## Parallel work / base

Started from `main` @ `262fb07` (PIP-63 Ask tab). Token/theme wiring only — no ViewModel/service/money changes.

## Test results

`cd PiPlanner && swift test` — **195 tests, 0 failures** (includes 7 `DesignTokensTests`).

## How to run tests

```bash
cd PiPlanner
swift test
```

## Out of scope

Screen restyles (PIP-69+); product behaviour from PIP-33..66; Android (PIP-68 twin).
