# AppsFlyer: ad attribution

**Files:** `AppStarter/Services/Analytics.swift`, `AppStarter/Services/Tracking.swift`, `Configuration/Info.plist`
**Config:** `APPSFLYER_DEV_KEY`, `APPLE_APP_ID` in `Configuration/Secrets.xcconfig`
**Cost:** free up to 12k conversions/month, then paid.

> Before your first paid campaign, read **[docs/launch-checklist.md](./launch-checklist.md)**. The code in this repo is the easy half. The dashboard toggles in that checklist are where attribution actually breaks, and every one of them fails silently.

---

## Why use it

**Only if you spend money on ads.** If all your installs are organic, skip this entirely: it adds a native dependency and buys you nothing.

If you do run ads, the question you need answered is *"which campaign, ad set, and creative produced people who pay?"* Nothing on the device knows that. The App Store install is a black box: a user taps an ad in TikTok, gets handed to the App Store, installs, and opens your app with no memory of where they came from.

A Mobile Measurement Partner is the piece that reconstructs the link. AppsFlyer receives an install postback from Apple (SKAdNetwork) and its own probabilistic match, joins them to the click, and tells the ad network "this install came from you" so the network can optimise. It's the same job for Meta, TikTok, Google and Apple Search Ads: one integration instead of four.

### Alternatives

| | Notes |
|---|---|
| **AppsFlyer** | Best free tier, best partner coverage. What this starter wires. |
| **Adjust** | Comparable. No free tier. |
| **Singular** | Strong on cost aggregation across networks. |
| **Branch** | Deep linking first, attribution second. Pick it if links matter more than ads. |
| **None** | Perfectly reasonable with no paid acquisition. SKAdNetwork alone still gives ad networks a coarse install signal. |

---

## Setup

1. Sign up at [appsflyer.com](https://www.appsflyer.com) and add your app (needs the App Store URL: an unreleased app can be added by bundle ID).
2. **Settings → App settings → Dev key**: one key per *account*, shared by all your apps.
3. ```
   // Configuration/Secrets.xcconfig
   APPSFLYER_DEV_KEY = your_dev_key
   APPLE_APP_ID = 6760719879   // digits from your App Store URL
   ```
4. Rebuild (⌘R).

**Then go do [docs/launch-checklist.md](./launch-checklist.md).** The single most common outcome of "I set up AppsFlyer" is a perfectly configured SDK sending events into a pipe that a dashboard default has switched off.

---

## Using it

Everything goes through `track()`, which fans out to PostHog *and* AppsFlyer:

```swift
Analytics.track("feature_used", ["feature": "export"])   // custom. PostHog + AppsFlyer
Analytics.track(Analytics.Event.tutorialCompletion)      // standard AppsFlyer name
```

### Use the standard event names

`Analytics.Event` holds AppsFlyer's standard vocabulary (`af_tutorial_completion`, `af_content_view`, `af_purchase`, …). Meta and TikTok recognise these natively, so they can optimise toward them with **no mapping work on your side**. Invent your own names and you inherit a mapping chore in three dashboards, forever.

Product-analytics-only events don't need to be in `Analytics.Event`, pass any string.

---

## Three things that are easy to get wrong

### 1. Never send revenue events from the client

RevenueCat already sends server-verified `af_start_trial` and `af_purchase` to AppsFlyer. **AppsFlyer does not de-duplicate SDK events against server-to-server events.** Send them from both and every purchase counts twice, its revenue counts twice, and your cost-per-paying-user reads at half its real value: the exact number you scale ad spend on.

`Analytics.track()` enforces this: events in `rcForwardedEvents` go to PostHog only. Use `Analytics.trackPurchase(…)` / `trackTrialStart(…)` and let it handle the split.

### 2. SKAdNetwork conversion values are client-only

Server-side events can never set a SKAN conversion value. Without on-device events, every SKAN postback your app produces says "install" and nothing more, so iOS campaigns have no trial or purchase signal to optimise toward, which is most of the value of running them.

`Analytics.logSKANConversion(_:)` sends deliberately-distinct `af_skan_trial` / `af_skan_purchase` events for this. Map those **only** in SKAN Conversion Studio, never in a partner postback mapping, reusing the standard names there recreates problem #1.

### 3. `af_app_opened` is Meta's entire install signal

Meta's AppsFlyer integration has **no install postback**. Mapped in-app events are its only inbound signal, and `af_app_opened` → `fb_mobile_activate_app` is the one that fires for every user. Without it, Meta's "Last iOS Install" goes stale and app-install campaigns fail validation with error `#1815437`, whose message, "application_id needs to be valid", points at completely the wrong thing.

`Analytics.start()` fires it on every launch. Don't remove it.

---

## SKAdNetwork

`Configuration/Info.plist` already contains 153 advertiser IDs under `SKAdNetworkItems`.

An ad network can only be credited with an install if its ID is in **your** Info.plist at the moment the ad is shown. The list is baked into the binary, add a network later and you need a new build, a new submission, and a review cycle before that channel can attribute anything. Including a network you never use costs nothing. So ship them all, before your first submission, even with no plans to advertise.

`Info.plist` also sets `NSAdvertisingAttributionReportEndpoint`, which tells iOS to send AppsFlyer a copy of every SKAN postback. Without it Apple posts only to the ad network, and AppsFlyer's SKAN dashboards stay empty forever with no error to explain why.

---

## App Tracking Transparency

See the header of `AppStarter/Services/Tracking.swift` for the full reasoning. The short version:

- ATT gates **only** the IDFA. AppsFlyer, PostHog, RevenueCat, SKAdNetwork and your ads all work without it.
- Saying yes buys deterministic user-level attribution. Saying no leaves you SKAdNetwork plus probabilistic matching, enough to optimise campaigns, not enough to reconcile individual users.
- Opt-in rates run ~20–40%.
- **Don't show the prompt unless you spend on ads.**
- If you do show it, show it **early**: AppsFlyer holds its install postback up to 60s waiting on the answer, and a prompt after onboarding plus a paywall routinely blows past that window, wasting the "yes" you worked for.
- `NSUserTrackingUsageDescription` must describe a benefit to the *user*. Generic wording is a routine rejection. Edit it in `Configuration/Info.plist`.

Enable with `ATT_ENABLED = YES` in `Secrets.xcconfig`, then rebuild.

---

## Verifying it works

1. **Growth tab → Fetch AppsFlyer ID.** A value means the SDK initialised.
2. **AppsFlyer dashboard → Overview.** Installs appear within an hour or so.
3. **A fresh install on a device that has never had the app.** AppsFlyer dedupes per device, so reinstalls don't produce a new install event: the same Apple ID on a different device is fine.

If the dashboard is empty but the ID resolves, the problem is almost always in [docs/launch-checklist.md](./launch-checklist.md), not in your code.

---

## Removing AppsFlyer

1. Xcode → target → *Frameworks, Libraries, and Embedded Content* → remove **AppsFlyerLib**; then project → *Package Dependencies* → remove `AppsFlyerFramework`.
2. Remove `NSAdvertisingAttributionReportEndpoint` from `Configuration/Info.plist` (or point it at your own MMP).
3. Delete `APPSFLYER_DEV_KEY` from `Secrets.xcconfig`, `Info.plist` and `AppConfig.swift`.

You do **not** need to edit `Analytics.swift`: every AppsFlyer block is inside `#if canImport(AppsFlyerLib)`, so removing the package compiles them out. `Analytics.track()` keeps working and forwards to PostHog only.

**Keep the `SKAdNetworkItems` array.** It costs nothing, and you cannot add it retroactively without a new binary and a new review.
