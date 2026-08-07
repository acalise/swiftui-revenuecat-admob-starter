# Google AdMob: ads

**File:** `AppStarter/Services/Ads.swift`
**Config:** `ADS_ENABLED`, `ADMOB_APP_ID`, `ADMOB_*_UNIT_ID` in `Configuration/Secrets.xcconfig`
**Default:** off.

---

## Should you use ads at all?

Usually the honest answer is *not as your primary model*. For most consumer apps, a subscriber is worth 10–100× an ad-supported user. Rough numbers for a US audience:

| | Revenue per user |
|---|---|
| Banner ad | ~$0.02–0.20 / month |
| Interstitial | ~$0.05–0.50 / month |
| Rewarded video | ~$0.10–1.00 / month |
| Subscription | $3–100 / year |

Ads make sense when:

- **You have real volume**: tens of thousands of DAU makes small numbers add up.
- **Nobody will pay for the use case**: utilities, casual games, one-off tools.
- **They're the free tier under a subscription.** This is the shape this starter wires up: `adsAllowed()` returns `false` for subscribers, so "remove ads" becomes a real benefit on the paywall at no extra work.

That last one is the most common good reason. Ads then serve two purposes: a little revenue from free users, and a visible reason to upgrade.

---

## Setup

### 1. Enable

```
// Configuration/Secrets.xcconfig
ADS_ENABLED = YES
```

Google's official **test** ad unit IDs are already wired in, so ads work immediately without an AdMob account. Rebuild (⌘R).

### 2. Real IDs (only when you're ready to ship)

1. Create an app at [admob.google.com](https://admob.google.com).
2. **App settings → App ID**: the `~` one (`ca-app-pub-XXXX~YYYY`).
3. Create ad units. Each gives you a `/` unit ID (`ca-app-pub-XXXX/ZZZZ`). Separate units per platform *and* per format: a banner ID in an interstitial slot fails to fill with an unhelpful error.

```
// Configuration/Secrets.xcconfig
ADMOB_APP_ID = ca-app-pub-XXXX~YYYY
ADMOB_BANNER_UNIT_ID = ca-app-pub-XXXX/ZZZZ
ADMOB_INTERSTITIAL_UNIT_ID = ca-app-pub-XXXX/ZZZZ
ADMOB_REWARDED_UNIT_ID = ca-app-pub-XXXX/ZZZZ
```

> ⚠️ `ADMOB_APP_ID` is **required in Info.plist whenever the SDK is linked**, even with `ADS_ENABLED = NO`. The Google Mobile Ads SDK checks for it at launch and throws `GADInvalidInitializationException` if it's missing: a hard crash before any of your code runs. That's why the default is Google's sample ID rather than blank.

> ⚠️ **Never load real ads against your own units in development.** Google calls that invalid traffic and bans accounts for it, not a warning, a ban, with unpaid earnings forfeited. Keep the test IDs until you ship, and add your device as a test device in the AdMob console if you need to check real units.

---

## Using it

```swift
BannerAdView()
```

Safe to leave anywhere: it collapses to zero height when ads are off, when the SDK isn't linked, when the user subscribes, or when an ad fails to fill. The layout is identical for paying users.

```swift
await Ads.preloadInterstitial()   // pre-load at a calm moment
await Ads.showInterstitial()      // show at a natural break

let earned = await Ads.showRewarded()
if earned { grantReward() }       // ONLY on true
```

### One question, one place

Every ad site should ask `Ads.canServeAds` rather than checking `AppConfig.adsEnabled` directly. It folds in the SDK check and the subscriber check, so the one banner someone forgot to gate can't show up in a paying customer's screenshot.

---

## Placement, which is most of the job

**Interstitials** are where apps earn one-star reviews. Rules that keep you out of trouble:

- At natural breaks only, level complete, task saved, article finished.
- Never on app open, never mid-task, never during onboarding. Apple rejects ads shown before the user has done anything.
- Frequency-cap them. Google's own guidance is no more than one per few minutes; users are less generous than that.
- Pre-load. They take seconds to fetch, so requesting one at the moment you want to show it means either a frozen UI or an ad that never appears.

**Rewarded** is the highest-value format and the only one users generally like, because it's an explicit trade. Grant the reward on `EARNED_REWARD` only, `CLOSED` fires whether or not they watched.

**Banners** are the least intrusive and the least lucrative. Anchor them at the bottom, out of the way of anything tappable.

---

## Privacy and consent

### iOS

- **ATT**: see `AppStarter/Services/Tracking.swift` and [appsflyer.md](./appsflyer.md). Without tracking permission you serve non-personalised ads, which pay less but work fine.
- **Init order matters.** `Ads.start()` runs *after* the ATT decision in `AppStarterApp.bootstrap()`. The Mobile Ads SDK reads the tracking status when it initialises; start it first and you're locked into non-personalised ads for the whole session.

### EEA / UK

Google's own policy requires a consent message before serving ads there. Use Google's UMP SDK:

The `swift-package-manager-google-mobile-ads` package already pulls in `GoogleUserMessagingPlatform` as a dependency, see the [consent docs](https://developers.google.com/admob/ios/privacy). Not wired up here because it needs a message you configure in the AdMob console for your specific app. **Do it before serving ads in Europe.**

### App Store privacy labels

Ads mean you collect data for tracking. Declare it in App Store Connect → App Privacy, at minimum *Identifiers → Device ID* under "Used for tracking". Getting this wrong is a rejection and, if it ships, a policy problem.

---

## Removing ads entirely

1. Xcode → target → *Frameworks, Libraries, and Embedded Content* → remove **GoogleMobileAds**; then project → *Package Dependencies* → remove `swift-package-manager-google-mobile-ads`.
2. Delete `AppStarter/Services/Ads.swift`, the `BannerAdView()` calls in `DesignSystemView` and `GrowthView`, the AdMob section of `GrowthView`, and `await Ads.start()` in `AppStarterApp`.
3. Remove `GADApplicationIdentifier` and `GADDelayAppMeasurementInit` from `Configuration/Info.plist`, and the `ADS_ENABLED` / `ADMOB_*` keys from `Secrets.xcconfig` and `AppConfig.swift`.

If you only want ads *off* rather than *gone*, set `ADS_ENABLED = NO` and stop, everything already no-ops, and you keep the option open.

Removing ads also removes one reason to subscribe, if "no ads" was on your paywall's benefit list in `PaywallView.swift`, take it off.
