# Koi fuel-price proxy (Cloudflare Worker)

A ~40-line Worker that caches + re-serves the Spanish government (minetur) fuel feed over
clean HTTPS. Lets the app drop its ATS exception and shields it from minetur outages.

## Deploy

```sh
cd proxy
npx wrangler deploy        # first run opens a Cloudflare login in the browser
```

You'll get a URL like `https://koi-fuel-proxy.<your-subdomain>.workers.dev`.
Test it: `curl https://koi-fuel-proxy.<your-subdomain>.workers.dev/province/28` → minetur JSON.

(Free tier covers this easily — one cached request per province per hour serves everyone.)

## Wire the app to it

In `Koi/Services/FuelPriceService.swift`, swap the base + path:

```swift
// before
private let base = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes"
let url = URL(string: "\(base)/EstacionesTerrestres/FiltroProvincia/\(code)")

// after
private let base = "https://koi-fuel-proxy.<your-subdomain>.workers.dev"
let url = URL(string: "\(base)/province/\(code)")
```

Then **delete the entire `NSAppTransportSecurity` block** from `Koi/Resources/Info.plist`
— the app now only talks to your Worker over modern HTTPS.

The response shape is unchanged (minetur JSON, BOM included — the app already strips it),
so nothing else needs to change.

## Optional next steps

- Custom domain (`fuel.yourdomain.com`) instead of `*.workers.dev`.
- Trim the payload server-side (return only the cheapest station per product near a point)
  to shrink the ~888-station response — would require a matching change in `FuelPriceService`.
- Extend beyond Spain when Koi goes multi-region (different national feeds behind the same proxy).
