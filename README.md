# TestiOS — PiPlanner

Local iOS demo app for PiPlanner ("Every Rupee Has a Plan.").

## Open the project

```bash
open PiPlanner/PiPlanner.xcodeproj
```

Requires Xcode 15+ / iOS 16+.

## Run unit tests (models, INR formatting, persistence)

```bash
cd PiPlanner && swift test
```

Or in Xcode: Product → Test (scheme **PiPlanner**).

## Layout

See Spec §4.2 — sources live under `PiPlanner/PiPlanner/` (`App`, `Models`, `Services`, …). Ticket notes: `docs/gts/piplanner/tickets/`.
