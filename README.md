# Koi

A calm, beauty-first iOS companion for every car in your life — owned, leased, financed,
on a subscription, or rented. Its soul is **"The Glance"**: open the app and in three
seconds you know everything's fine, or exactly what's coming — then close it.

> Status: **scaffold**. Design-system foundation (tokens, fonts, light/dark) + one proof
> screen (the Glance all-clear). No data layer or navigation yet. See the roadmap below.

## Stack

- **SwiftUI**, iOS 17+, local-first (no login wall planned).
- Project is defined by [`project.yml`](project.yml) and generated with **XcodeGen**
  (the `.xcodeproj` is git-ignored; `project.yml` is the source of truth).

## Generate & run

```bash
brew install xcodegen      # one-time, if not installed
xcodegen generate          # creates Koi.xcodeproj from project.yml
open Koi.xcodeproj          # then ⌘R in Xcode (iPhone simulator)
```

Re-run `xcodegen generate` whenever files are added/removed.

## Layout

```
Koi/
  App/            KoiApp (entry) · ContentView (host + dev light/dark toggle)
  DesignSystem/   KoiColors · KoiFonts · KoiMetrics · KoiCard · RippleMark · Bloom
  Views/          GlanceAllClearView  ← the proof screen
  Resources/      Info.plist · Assets.xcassets · Fonts/*.ttf
Scripts/          convert-fonts.sh
```

## Design system

Ported from the design handoff (`design_handoff_koi_car_companion`). Koi's language is a
deliberate sibling of the **Sure** finance design system — same Geist type, same
shadow-border card, same warm-neutral surfaces — with a warm-paper canvas and sage/ochre
accents layered on top.

- **Color** — `KoiColors`: every token has an exact light + dark value (dynamic `UIColor`).
  Sage = all-clear/primary; ochre = coming-up; red = overdue **only**. No gradients except
  the all-clear bloom.
- **Type** — `KoiFont` + `KoiTextStyle`: Geist Sans (workhorse weight 500) for UI;
  **Geist Mono** for every meaningful number (money, efficiency, countdowns, dates-as-data).
- **Elevation** — `koiCard()`: soft shadow + 1px alpha ring. Borders are always 1px alpha,
  never solid gray.
- **Brand** — `RippleMark` (the concentric-pond "koi" mark) and `Bloom` (the slow ~7s
  breathing sage disc behind the all-clear headline).

### Fonts

Geist / Geist Mono ship in the handoff as **`.woff2`**, which iOS cannot bundle. They were
transcoded to `.ttf` (wrapper stripped, glyphs untouched) into `Koi/Resources/Fonts/` and
registered via `UIAppFonts`. To regenerate:

```bash
pip3 install --user fonttools brotli
Scripts/convert-fonts.sh /path/to/design_handoff_koi_car_companion/sure-tokens/fonts
```

## Known scaffold shortcuts (replace as the app grows)

- **Icons** are SF Symbols placeholders; the handoff requires **Lucide** (bundle + swap).
- **Fonts** use `fixedSize` for pixel-exact mock fidelity; production should adopt
  `relativeTo:` for Dynamic Type.
- The **light/dark toggle** in `ContentView` is a dev affordance; remove once navigation lands.
- On the Glance, the **active-car line** and the **Last fill-up** card are real (read the
  store). **Next up** and **Diesel nearby** stay static sample until reminders / the
  fuel-price feed land (P6/P8).
- Persistence is a local JSON file in Application Support (sync-ready: stable UUIDs +
  timestamps). Swap for SwiftData later if wanted.

## Roadmap

- **P1** — foundation + Glance all-clear proof. ✅
- **P2** — data spine: `Plan ▸ Car` model + local-first store (`Garage`). ✅
- **P3** — first-run (Own/Plan/Borrow) → add a car → real Glance. ✅ all three forms
  (owned, on-a-plan, rental).
- **P4** — Garage (residents/guests) · Car detail (timeline) · quick-add Log with keypad
  (derives L/100km, updates Glance + timeline). ✅
- **P5** — subscription **Swap** + rental **Return** (the Plan▸Car proof).
- **P6** — coming-up status engine + reminders + Glance Direction B (populated state).
- **P7** — relationship-aware insurance + Wallet-style card + docs vault.
- **P8** — live Spain fuel-price hook ("diesel nearby") + Settings.
- **P9** — polish: haptics, spring motion, edge states, per-car accent derivation.
