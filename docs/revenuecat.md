# RevenueCat: subscriptions

**Files:** `AppStarter/Services/Subscriptions.swift`, `AppStarter/Features/Paywall/PaywallView.swift`
**Config:** `REVENUECAT_API_KEY`, `RC_ENTITLEMENT`, `RC_OFFERING` in `Configuration/Secrets.xcconfig`
**Cost:** free under $2.5k/month tracked revenue, then a percentage. Free tier is generous enough that most apps never pay.

---

## Why use it

StoreKit 2 is genuinely good, and for a single non-consumable unlock you don't need anything else. For **subscriptions**, here's what you take on if you go direct:

- **Receipt validation.** Apple's `verifyReceipt` has separate sandbox and production endpoints, and you have to try one and fall back to the other. Get it wrong and TestFlight users appear unsubscribed.
- **A server.** Local receipt validation is trivially bypassed. Real validation needs a backend you now operate.
- **Renewal webhooks.** Subscriptions renew, lapse, enter billing retry, get refunded, get upgraded mid-period, and get shared through Family Sharing. Each is a different state your app has to understand.
- **Restore across devices and reinstalls.** Required by App Review, and the reviewer *will* test it on a clean device.
- **All of it again for Google Play** if you ever ship Android, with an entirely different API.

That's weeks of work whose failure mode is "a paying customer loses access", and no user can see any of it. RevenueCat replaces the lot with `getCustomerInfo()`.

**The reason that actually matters for this starter:** RevenueCat is the join point between purchases and ad spend. Its AppsFlyer and Apple Search Ads integrations are what let you measure *cost per paying subscriber* rather than cost per install. For a subscription app, a cheap install that never converts is worth nothing, so cost-per-install is a number that can point you confidently in the wrong direction.

### When not to use it

- One-time non-consumable purchases with no renewal (a "remove ads" unlock). StoreKit 2 alone is genuinely fine, `Product.products(for:)`, `product.purchase()`, done.
- You already run subscription infrastructure for a web product.
- You're at a revenue scale where the percentage exceeds the cost of owning it. You'll know.

---

## Setup

### 1. Dashboard

1. Create a project at [app.revenuecat.com](https://app.revenuecat.com).
2. **Apps** → add an iOS app. It needs your bundle ID and an App Store Connect **In-App Purchase Key** (App Store Connect → Users and Access → Integrations → In-App Purchase). Without that key RevenueCat can't validate receipts server-side.
3. **Products** → add the product identifiers you created in App Store Connect.
4. **Entitlements** → create one called `pro` and attach every product to it.
5. **Offerings** → create one, mark it **current**, and add packages (Monthly, Annual, …).

### 2. Keys

Project → **API keys** → copy the **public SDK key** (`appl_…`).

```
// Configuration/Secrets.xcconfig
REVENUECAT_API_KEY = appl_xxxxxxxxxxxx
RC_ENTITLEMENT = pro
```

Rebuild (⌘R): these are baked into Info.plist at build time, so a re-run is required, not just a relaunch.

### 3. Sandbox testing

Create a **Sandbox Apple ID** in App Store Connect → Users and Access → Sandbox. Sign into it on the device under *Settings → Developer → Sandbox Apple Account*, **not** the main App Store account, which will silently charge you real money.

Sandbox subscriptions renew on a compressed clock: a 1-month subscription renews every 5 minutes and auto-cancels after 6 renewals. Useful for testing renewals; confusing if you don't expect it.

---

## Using it

```swift
struct Feature: View {
    @Environment(Subscriptions.self) private var subscriptions

    var body: some View {
        if subscriptions.isPro {
            TheRealThing()
        } else {
            UpgradePrompt()
        }
    }
}
```

`Subscriptions` is `@Observable`, so any view that reads `isPro` re-renders the moment the entitlement changes, including from a purchase made on another device.

Outside a view:

```swift
if Subscriptions.shared.isPro { … }
await Subscriptions.shared.refresh()   // force a re-read
```

Show the paywall:

```swift
.sheet(isPresented: $showPaywall) { PaywallView() }
```

### Check entitlements, never product IDs

```swift
if subscriptions.isPro { … }                        // ✅
if productID == "com.app.annual" { … }              // ❌
```

Entitlements are the indirection that lets you add a lifetime tier, run a regional price test, or grandfather old subscribers: all from the dashboard, with no app release. Product-ID checks force a release for each of those, and they get out of sync the moment a second product exists.

---

## Development without a key

With no RevenueCat key set, everything still runs:

- `loadPlans()` returns nothing, and the paywall shows a short explainer instead of plans.
- `purchase()` grants a **local debug unlock** so you can design and test everything behind the paywall before App Store Connect exists.
- Settings → Developer has **Force Pro** / **Force Free** / **Clear** buttons.

`Force Free` deliberately overrides a *real* entitlement, so you can check the free experience without cancelling a sandbox subscription. Both overrides are wrapped in `#if DEBUG`: a release build always trusts RevenueCat, and the buttons aren't even compiled in.

---

## Two calls that fail silently if you skip them

Both are in `start()` in `AppStarter/Services/Subscriptions.swift`. Neither produces an error, and the dashboard reports "Active" in both broken cases.

### `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()`

Sends Apple's AdServices token to RevenueCat, which is what maps Apple Search Ads conversions to actual subscribers **per keyword**. Turning on the Apple Ads integration in the RevenueCat dashboard does nothing without this call, you'll get cost-per-install per keyword and never cost-per-subscriber.

### `Purchases.shared.attribution.setAppsflyerID(_:)`

RevenueCat keys every event it forwards to AppsFlyer on the `$appsflyerId` subscriber attribute. Leave it unset and RevenueCat drops **all** of those revenue events. Installs keep attributing normally (that's AppsFlyer's own SDK), which is exactly what hides the gap: the funnel looks alive right up to the events you actually care about.

**How to verify both.** Run a debug build (`Purchases.logLevel = .debug` is already set) and watch the console. RevenueCat prints its synced subscriber attributes. Seeing `$appsflyerId` with a real value is the single line that proves the pipe works. It works even with ATT denied.

---

## Paywall rules App Review enforces

`PaywallView.swift` handles all four. Keep them if you rewrite the layout.

| # | Requirement | Guideline |
|---|---|---|
| 1 | Visible **Restore Purchases** control | 3.1.1 |
| 2 | Visible way to **dismiss** the screen | 3.1.2 |
| 3 | **Price, period and renewal terms** next to the buy button | 3.1.2 |
| 4 | Working **Terms** and **Privacy Policy** links | 3.1.2 / 5.1.1 |

Also required in App Store Connect itself: a subscription **group display name**, and the same Terms/Privacy URLs on the app listing.

Set `TERMS_URL` and `PRIVACY_URL` in `Secrets.xcconfig` before submitting: the defaults point at `example.com`.

---

## Displaying prices

Always render `plan.price`: the localised string RevenueCat returns:

```swift
Text(plan.price)        // "$29.99", "¥3,000", "R$ 149,90"
```

Never hardcode. A hardcoded "$29.99" shown to a user whose store will charge ¥4,500 is both a bad experience and, if it's on the paywall, a rejection.

---

## Optional: RevenueCat's hosted paywalls

`react-native-purchases-ui` renders paywalls you design in the RevenueCat dashboard, so you can change layout, copy and pricing without an app release. That's worth a lot once you're iterating on conversion.

Add the **RevenueCatUI** product from the already-linked `purchases-ios` package (Xcode → target → *Frameworks, Libraries, and Embedded Content* → **+** → RevenueCatUI), then:

```swift
import RevenueCatUI

struct PaywallScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in dismiss() }
    }
}
```

This starter ships the hand-built version instead, because a starter's paywall should be readable, `PaywallView.swift` shows the whole flow (fetch offerings → render → buy → handle cancel → dismiss) in plain SwiftUI. Once that's clear, swapping in the hosted version is the snippet above.

---

## Removing RevenueCat

1. Xcode → target → *Frameworks, Libraries, and Embedded Content* → remove **RevenueCat**; then project → *Package Dependencies* → remove `purchases-ios`.
2. Delete `AppStarter/Services/Subscriptions.swift` and `AppStarter/Features/Paywall/PaywallView.swift`.
3. Remove `Subscriptions` from `AppStarterApp.swift` (the `@State`, the `.environment`, and the `await subscriptions.start()`).
4. Remove `@Environment(Subscriptions.self)` and every `isPro` branch from `ProfileView`, `SettingsView`, `GrowthView`, and `AppStarter/Services/Ads.swift` (`canServeAds` reads `isPro`).
5. Delete `REVENUECAT_API_KEY` / `RC_ENTITLEMENT` / `RC_OFFERING` from `Secrets.xcconfig`, `Info.plist` and `AppConfig.swift`.

Steps 2–4 are only needed if you're removing *subscriptions*. If you just want to swap RevenueCat for raw StoreKit 2, keep `Subscriptions.swift`'s public surface (`isPro`, `plans`, `purchase`, `restore`) and reimplement the internals: every call site is written against that API, not against RevenueCat types.
