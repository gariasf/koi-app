# Koi localization spec (es-ES · ca · nb · fr-FR)

One spec, two native implementations. Android is a 1:1 port of iOS, so the message
templates are designed once here and emitted into both catalog formats.

## Decisions (locked)
- **Scope:** app UI + App Store/Play metadata + marketing site + privacy policy.
- **Translation:** AI-generated for all four; **Catalan + Norwegian get a native review before they ship** (compound spelling, calque risk). Spanish + French are AI ship-quality but still pass the tone pass below.
- **Rollout:** Phase 0 infra (English, keys in place) → Spanish → batch ca/nb/fr → store metadata + screenshots + site.
- **Formality (never mix within a language):** es **tú** · ca **tu** · fr **vous** · nb **du**.
- **Region ≠ language.** The Spain-only fuel feed stays gated on *region* (`Locale.region == "ES"`), independent of UI language. A French speaker in Spain gets French UI + Spanish fuel prices.

## Architecture
**iOS** — `Koi/Resources/Localizable.xcstrings` (String Catalog), `es,ca,nb,fr` in `knownRegions`. Static `Text("…")`/`Label("…")` auto-extract. Reusable component params retype `String → LocalizedStringKey`. Enum accessors / `KoiFormat` units / computed copy → `String(localized:)` / `LocalizedStringResource`. **Plus `InfoPlist.strings` per locale** for `NSLocationWhenInUseUsageDescription` (the catalog does NOT cover Info.plist).
**Android** — `values/strings.xml` + `values-es|ca|nb|fr/` (+ `plurals.xml`). Literals → `stringResource`/`pluralStringResource` at call sites (components keep `String` params). `resConfigs "en","es","ca","nb","fr"`, `res/xml/locales_config.xml` + `android:localeConfig`, lint `MissingTranslation = error`. Escape apostrophes in XML.
**Leave alone:** number/date/money cores (already locale-aware via `.formatted` / `NumberFormat` / `DateTimeFormatter(Locale)`), and `KoiFormat.normalize` (last-separator-as-decimal). No hand-assembled date/month strings — always through the formatter.

## Audit rules (the silent traps)
- iOS: `Text(variable)` renders **verbatim** — never localizes. Any `Text(identifier)` is a bug until its source is `String(localized:)` or a `LocalizedStringKey` param. ~95 sites.
- No hand-built date/month/weekday strings — always `DateTimeFormatter`/`.formatted(.dateTime…)` with `Locale.current`.
- Android: unescaped `'` truncates the string at build.
- Region names via `Locale.localizedString(forRegionCode:)`, never a hardcoded "Spain".

## Key spec — the hard string families (ICU, designed once)
Each becomes a full template per language; **never** built by code concatenation/affix.

| key | English | shape |
|---|---|---|
| `countdown.inDays` | "in N days" | plural (`%lld`); separate non-numeric keys `countdown.today/tomorrow/overdue` (FR folds 0→singular) |
| `gauge.reset.inDays` | "resets in N days" | plural; `gauge.reset.today` separate |
| `glance.comingUp.{one,couple,few}` | "One thing" / "A couple" / "A few … mostly {name}" | **editorial buckets, NOT CLDR plurals**; `{name}` a bare `%@` token; hand `switch`, not `<plurals>` |
| `gauge.mileageThis.{month,year}` | "Mileage this month/year" | two full keys, selected on `CapPeriod` — never `"Mileage this " + noun` |
| `plan.cap.unit.{month,year}` | "km/mo" / "km/yr" | two keys, not affixed |
| `ownership.{finance,lease,subscription}.since` | "Financing since {m yr}", "On a {kind} since {m yr}" | one template per `PlanKind`, positional `%@`; drop `.lowercased()` |
| `glance.heroSubtitle` | "{used} of {cap} km this {period}" | positional `%1$@ / %2$@ / %3$@` |
| `format.efficiency` / `format.distance.{m,km}` / `format.perLiter` | "L/100km", "m away", "€/L" | catalog format strings; currency symbol from formatter, not literal € |
| `swap.everyMonths` / `fuel.updatedAgo` | "Swap every N months" / "Updated Nm ago" | plural |
| One shared `Countdown` helper per platform (today/tomorrow/overdue/in-N-days/in-N-weeks) — replaces today's triplicated logic. |

## Tone glossary (anchor phrases — all four must match this register, incl. es/fr)
Koi's voice is calm, warm, plain, unhurried. MT flattens exactly this — every language passes a tone check against these anchors.
- "All clear" → reassurance, not "OK"/"Todo correcto" stiffness. es **"Todo en orden"** · ca **"Tot en ordre"** · fr **"Tout est en ordre"** · nb **"Alt i orden"**.
- "No rush. Koi will nudge you again closer to the time." — keep the unhurried promise, not a curt "We'll remind you."
- "Open, breathe, close." — three calm beats; preserve the rhythm.
- "Everything, quietly handled." — the marketing anchor.
- AVOID: imperatives that nag, exclamation marks, corporate "Manage your vehicles."

## Domain glossary
| EN | es (tú) | ca (tu) | fr (vous) | nb (du) |
|---|---|---|---|---|
| car | coche | cotxe | voiture | bil |
| garage | garaje | garatge | garage | garasje |
| plan | plan | pla | formule | abonnement |
| lease | renting | rènting | location longue durée (LLD) | leasing |
| finance | financiación | finançament | financement | finansiering |
| subscription | suscripción | subscripció | abonnement | abonnement |
| mileage cap | límite de kilometraje | límit de quilometratge | plafond kilométrique | kilometergrense |
| fill-up / refuel | repostaje | repostatge | plein | fylling |
| odometer | cuentakilómetros | comptaquilòmetres | compteur | kilometerteller |
| reminder | recordatorio | recordatori | rappel | påminnelse |
| inspection | ITV | ITV | contrôle technique | EU-kontroll |
| insurance | seguro | assegurança | assurance | forsikring |
| carry-over (mileage) | acumulado | acumulat | report | overført |
| paid off | pagado del todo | pagat del tot | soldé | nedbetalt |

> nb compounds are ONE word: `kilometergrense`, `kilometerteller` (the #1 Norwegian MT error is splitting them). ca elisions: `l'assegurança`, `d'`. Catalan province picker labels: prefer Catalan toponyms (Lleida/Girona) for the largest non-Spanish ES audience.

## Surfaces beyond the SwiftUI/Compose string layer (don't forget)
- **`InfoPlist.strings`** per locale — location-permission prompt (system UI, shows in user's language; English here = visible leak / possible review reject). `CFBundleDisplayName` "Koi" stays (proper noun).
- **App Store screenshot captions** live in `appstore/frame.html` (JS `SLIDES` array) — a *second* English copy-deck, plus the baked-in app UI inside the PNGs. Parameterize captions by locale + re-render per language.
- **Store metadata** (title/subtitle/description/keywords/release notes) per locale; per-locale **privacy-policy URL** in App Store Connect (`/es/privacy/` …) — App Review flags mismatch.
- **CI completeness gate** (none today): Android lint `MissingTranslation=error` + a custom iOS step failing on `"state":"new"` catalog entries for shipping locales.
- Confirmed **n/a:** no notifications/Widget/Live Activity strings yet (in-app "nudge" only); no RTL (none of es/ca/nb/fr are RTL).
