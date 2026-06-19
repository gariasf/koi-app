# Koi — App Store submission checklist (free · local-only · non-trader)

This is the minimum to publish Koi as a **free**, **local-only** app, with **no
monetization**, **no family/CloudKit sync**, and **not registered as a trader**.

## 0. One-time account
- [ ] **Apple Developer Program** membership — $99/yr (the only cost). Individual
      enrollment is fine; note that your legal name appears as the "Seller."

## 1. In the project (already done / in repo)
- [x] **`PrivacyInfo.xcprivacy`** — declares no tracking, no data collection, and the
      one required-reason API Koi uses: `NSPrivacyAccessedAPICategoryUserDefaults`
      with reason **`CA92.1`** (app's own defaults, e.g. the theme setting).
- [x] **`ITSAppUsesNonExemptEncryption = NO`** in `Info.plist` — Koi only uses
      standard HTTPS, which is exempt. This stops the per-build encryption prompt.
- [x] **Privacy policy** — text in `docs/privacy-policy.md`, also shown in-app under
      *Settings → Privacy*.

## 2. Host the privacy policy (App Store Connect requires a URL)
- [ ] Publish `docs/privacy-policy.md` at a public URL. Easiest: enable **GitHub
      Pages** on this repo (Settings → Pages → Source: `main` / `/docs`). The page
      will be served at e.g. `https://<user>.github.io/<repo>/privacy-policy`.
- [ ] Put that URL in the in-app link constant (`PrivacyPolicyView.onlineURL`) and in
      App Store Connect.

## 3. In App Store Connect — App Privacy ("nutrition label")
- [ ] **Data Collection: "No, we do not collect data from this app."** → results in
      **Data Not Collected**. (True: nothing leaves the device to us; the region code
      goes directly to a government feed, which does not count as collection by us.)

## 4. In App Store Connect — Trader status (EU Digital Services Act)
- [ ] Declare **Non-trader**. Allowed because the app is free with no in-app
      purchases, ads, or other monetization. (If you ever add a price or IAP, you
      become a **trader** and your name + address + phone + email are shown publicly
      on the listing — use a business/forwarding address if so.)

## 5. In App Store Connect — listing
- [ ] **Age rating** questionnaire → 4+ (no objectionable content).
- [ ] **Encryption**: when asked, answer that the app does **not** use non-exempt
      encryption (the Info.plist key answers it automatically).
- [ ] Screenshots, name, subtitle, description, keywords, support URL.

## Not required at this scope
- GDPR machinery (DPO, consent banners, DPA): not needed while you collect nothing
  and store everything on-device.
- Tax/banking forms: only needed if you monetize.
- In-app account deletion: only needed if the app has accounts. Koi has none.
- Fuel-data attribution: crediting the minetur feed (already done in *Settings →
  Region*) is good manners, not a legal requirement.

## Future trip-wires (would raise obligations)
- **Cloudflare fuel proxy that logs IPs** → you become a GDPR data controller for
  those logs; the privacy policy must then add a lawful basis + retention + contact.
- **CloudKit family sharing** → data goes to iCloud as your responsibility; full
  GDPR privacy policy required.
- **Any price / IAP / ads** → DSA trader status (public contact details) + tax setup.
