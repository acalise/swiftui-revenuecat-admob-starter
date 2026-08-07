# Launch checklist: the dashboard half

Wiring the SDKs is the easy part. This file is the other half: the console settings, in the order they have to happen, that decide whether attribution works.

**Every failure listed here is silent.** No exception, no warning, no red banner. Configs look perfect while nothing flows. That's what makes them expensive: you find out weeks into an ad campaign, from a number that was wrong the whole time.

Work through it before your first campaign, not after.

---

## 0. Before your first App Store submission

Things that require a **new binary and a new review** if you skip them. Do them now even if you have no plans to advertise.

- [ ] **`SKAdNetworkItems` in Info.plist.** Already in `Configuration/Info.plist` (153 entries). An ad network can only be credited with an install if its ID is in your binary at the moment the ad is shown.
- [ ] **`NSAdvertisingAttributionReportEndpoint`.** Already in `Configuration/Info.plist`. Without it, Apple sends SKAN postbacks only to the ad network and your MMP's SKAN dashboards stay empty forever.
- [ ] **`NSUserTrackingUsageDescription`**, if you'll ever show the ATT prompt. Edit `ATT_REASON` in `app.config.ts`, generic wording is a routine rejection.
- [ ] **App Store Connect → App Privacy** filled in truthfully. Ads and attribution both count as tracking.

---

## 1. AppsFlyer

### 1a. `Aggregated Advanced Privacy` must be **OFF**

**AppsFlyer → Settings → App settings → (select the app) → Aggregated Advanced Privacy**

This is **on by default for every new iOS app** and it overrides your postback settings. With AAP on and no ATT prompt, essentially every user is non-consenting, so **zero** install postbacks reach your ad partners, while the integration page reads "Active" and your config looks flawless.

> Symptom: your app sits at "Pending verification" in TikTok's Events Manager with no events, for days, with everything else configured correctly.

⚠️ The app-settings page tends to default to whichever app is first in your account. **Check the selector says the right app.**

### 1b. In-app event postbacks

**AppsFlyer → Partner Marketplace → (each partner) → Integration**

- Install postback: **all media sources, including organic**
- In-app events: **on**
- Map `af_purchase` → the partner's purchase event, with **values and revenue**
- Map `af_start_trial` → the partner's trial event

### 1c. SKAN Conversion Studio

Map only `af_skan_trial` / `af_skan_purchase` here. **Never** map them in a partner postback mapping, see [appsflyer.md](./appsflyer.md#three-things-that-are-easy-to-get-wrong) for why that double-counts every purchase.

---

## 2. RevenueCat → AppsFlyer

**RevenueCat → Project → Integrations → Attribution → AppsFlyer**

- [ ] Paste your AppsFlyer **dev key** into both the production and sandbox key fields.
- [ ] Set the iOS App ID (`id1234567890`) in both the production and sandbox fields.
- [ ] **Rename the events.** RevenueCat's defaults are `rc_initial_purchase`, `rc_trial_started`, and so on. AppsFlyer's partner mappings match on `af_purchase` and `af_start_trial`. Left at the defaults, RevenueCat sends events that nothing downstream is listening for.

| RevenueCat event | Rename to |
|---|---|
| Initial purchase | `af_purchase` |
| Trial started | `af_start_trial` |
| Trial converted | `af_purchase` |

  On an annual-with-trial product, the trial *conversion* is the payment, that's why it maps to `af_purchase` too.

- [ ] **Confirm `Purchases.setAppsflyerID()` runs** (it's in `start()` in `AppStarter/Services/Subscriptions.swift`). RevenueCat keys every forwarded event on the `$appsflyerId` attribute; unset, it drops all of them silently. Verify in a debug build: RevenueCat logs its synced subscriber attributes, and `$appsflyerId` with a real value is the proof.

---

## 3. RevenueCat → Apple Search Ads

**RevenueCat → Integrations → Apple Ads**

- [ ] Enable the integration.
- [ ] **Confirm `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()` runs** (`AppStarter/Services/Subscriptions.swift`). The dashboard toggle alone does nothing. This is the step people skip, and without it you get cost-per-install per keyword and never cost-per-*subscriber* per keyword.
- [ ] Set up **Scheduled Data Exports** (RevenueCat → Integrations) to cloud storage. Transaction-level data you can join against your Apple Ads spend export. The analysis loop, spend export + transaction export → find 3× ROAS keywords, kill the losers, scale the winners: is the entire reason to do any of this.

---

## 4. Meta

Do these **in order**; step 3 is the one everyone misses.

1. **Create a Meta dev app** at developers.facebook.com with the "app ads" use case → add the iOS platform with your bundle ID and numeric App Store ID → set a privacy URL → **publish it live**.
2. **Authorise the ad account in BOTH places**: Advanced settings *and* the app-ads use-case wizard (Use cases → Customize). Basic settings does not cover the wizard.
3. **AppsFlyer → Partner Marketplace → Meta ads → paste the Meta dev app ID into `Facebook App Id`.** An integration toggled Active with an empty app ID silently sends nothing. If your dev app was created after you set up AppsFlyer, this field **is** empty.
4. **`Advanced data sharing` must be ON** (same partner page, under Data sharing). **Off by default.** Off means AppsFlyer sends Meta events only from ATT-consented devices, which, with no ATT prompt, is approximately nobody.
5. **Business Manager**: app added to Business settings → Apps and connected to the ad account. Instagram account connected to the ad account *and* linked to the Facebook Page (the Page link needs an IG login and is what makes the @handle selectable as an ad identity).

### Diagnosing Meta

**Error `#1815437`, "application_id needs to be valid"** does not mean your app ID is wrong. It means Meta has **no event signal** for the app. Use [App Ads Helper](https://developers.facebook.com/tools/app-ads-helper): if it shows *Last iOS Install: Unavailable* and *Optimized CPM ✗*, the pipe is dead, work back through steps 3 and 4.

In Events Manager, "App installs" inactive while "Activate app" trickles in is the specific signature of step 4 being off.

Fastest way to confirm a fix: one fresh install on a device that has **never** had the app. Reinstalls are deduped.

---

## 5. TikTok

1. **Register the app**: Ads Manager → Tools → Events → App. Needs the full store URL. Produces a **TikTok App ID**. Connection method = **MMP (AppsFlyer)**.
2. **AppsFlyer → Partner Marketplace → TikTok For Business**: paste the TikTok App ID into General settings; install postback = all media sources including organic; in-app postbacks on with `af_purchase` → Purchase (values and revenue) and `af_start_trial` → StartTrial.
3. **App verification needs at least one received postback**, and TikTok batches the badge (24–48h). For a low-volume app, force it with one fresh install on a device that never had the app, install from the App Store *and* open it. The Test-event tab is SDK-only and useless for MMP apps. Verification does **not** block ad delivery, only event reporting and optimisation.
4. **SKAN 4.0**: align TikTok (Events Manager → app → Settings → "Update to SKAN 4.0") with AppsFlyer's Conversion Studio mode. The button is **locked while a dedicated campaign is live**: do it before you launch, or while paused.

### The "0 results" trap

TikTok iOS app campaigns are "iOS 14 dedicated", so the campaign grid's **Results** column counts SKAdNetwork conversions, not the MMP pipe. It reads **0 forever** unless you add the **"Results (SKAN)" columns via Custom Columns**. SKAN postbacks also lag 24–72h by Apple's design, don't judge a campaign the same day.

---

## 6. Before you spend money

- [ ] A fresh install on a never-seen device shows up in AppsFlyer.
- [ ] A sandbox purchase produces `af_purchase` in AppsFlyer **exactly once** (twice means you're sending it client-side as well as through RevenueCat, see [appsflyer.md](./appsflyer.md)).
- [ ] `$appsflyerId` appears in RevenueCat's subscriber attributes.
- [ ] Meta's App Ads Helper shows a recent iOS install.
- [ ] TikTok's Events Manager shows the app verified.
- [ ] Your paywall passes the four App Review rules in [revenuecat.md](./revenuecat.md#paywall-rules-app-review-enforces).

---

## Campaign hygiene

Once it's all flowing:

- **Judge a creative after ~$100 spent.** Less than that is noise.
- **Kill at 2× target CPA with zero conversions.**
- **Scale winners +20%/day.** Bigger jumps reset the learning phase.
- **Optimisation ladder:** Install → StartTrial (after ~30–50 trial events have reached the network) → Purchase. Don't skip ahead; the learning phase needs roughly 20 conversions/week to stabilise.
- **The decision metric is cost per paying subscriber**, not cost per install. Everything in this document exists to make that number trustworthy.
