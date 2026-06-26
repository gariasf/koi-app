# Koi

**Your cars, calmly.** A calm, local-first iOS companion for every car in your life — owned, leased,
financed, on a subscription, or borrowed. Open it, see that everything is fine (or the one thing that
needs you), and get on with your day. No dashboards, no logs to keep up with.

Its soul is **the Glance**: three seconds of reassurance, then it gets out of the way.

## What it does

- **The Glance** — one screen showing the thing that needs you, or nothing at all.
- **Mileage carry-over** — for a lease or subscription with a distance cap, a live gauge that *banks*
  the months you drive less. Unused kilometres roll over to the end of the term, so you see your real
  allowance, not just this month's.
- **Cheapest fuel nearby** — in Spain, live government fuel prices on the screen you already open. The
  rest of the app works worldwide.
- **Garage** — every car in one quiet home. A financed car can be marked *paid off* and quietly become
  yours (reversible).
- **Story** — fills, costs and milestones gathered by month, without effort.
- **Documents vault** — registration, insurance and inspection, kept on device.
- **Localized** — English, Spanish, Catalan, Norwegian and French.

## Quiet by design

Everything stays on your iPhone. No account, no sign-in, no servers, no tracking. The only thing Koi
ever sends is the region you choose, so it can fetch local fuel prices.

## Stack

- **SwiftUI**, iOS 17+, local-first.
- The Xcode project is generated from [`project.yml`](project.yml) with **XcodeGen** — `project.yml`
  is the source of truth; the `.xcodeproj` is git-ignored.

## Build & run

```bash
brew install xcodegen      # one-time
xcodegen generate          # creates Koi.xcodeproj from project.yml
open Koi.xcodeproj          # ⌘R on an iPhone simulator
```

Re-run `xcodegen generate` whenever files are added or removed.

Dev launch args: `-seed` loads sample data; `-garage` opens on the Garage tab (used for screenshots).

## Tests

```bash
xcodebuild test -project Koi.xcodeproj -scheme Koi \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

`Tests/` holds the logic net — money/date wire format, mileage carry-over, the finance→owned payoff
lifecycle, countdown/urgency and swap lineage. CI runs them on every push.

## Layout

- `Koi/App` — app shell, routing, the tab bar.
- `Koi/Models` — `Garage` (store + derived reads + mutations) and the domain types.
- `Koi/Views` — Glance, Garage, CarDetail, Log, Settings, Mileage history, the add/edit sheets.
- `Koi/DesignSystem` — colours, type, the soft-shadow card, controls, formatters, Phosphor icons.
- `Koi/Resources` — assets + the `Localizable.xcstrings` catalog.
- `appstore/` — screenshot framing and the per-locale store metadata deck.

## Related

- **Android** — a native Kotlin/Compose port lives in a sibling repo (same logic, same JSON export
  format, so you can migrate iPhone ↔ Android).
- **Site & privacy** — [koi.gariasf.com](https://koi.gariasf.com).
