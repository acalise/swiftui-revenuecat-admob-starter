# swiftui-revenuecat-admob-starter

> A native SwiftUI starter with the boring, load-bearing parts already done: a design system that doesn't drift, a paywall that passes App Review, subscriptions, attribution, analytics, and ads. **Every integration is optional and inert until you add a key.**

Clone it, open it, change the accent color, ship.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17%2B-black?logo=apple)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Observable-blue)](https://developer.apple.com/documentation/swiftui)

SwiftUI on iOS 17+, `@Observable` throughout, Swift Package Manager only. No CocoaPods, no workspace, no bridging layer.

---

## Why this exists

Most SwiftUI starters give you a tab bar, a theme, and a component gallery, then stop exactly where the tedious work begins. The parts that actually take a week and are easy to get subtly wrong are:

- a **paywall** that satisfies the four things App Review checks for,
- **subscription state** that survives reinstalls, cold starts and offline launches,
- **attribution** wired so ad spend can be judged against revenue rather than installs,
- **analytics** that answers *where people give up*,
- and an SDK **startup order** that quietly costs you money when it's wrong.

Those are here, working, with the reasoning written into the files themselves. So is a [launch checklist](./docs/launch-checklist.md) of the dashboard settings that silently break attribution, none of which live in code, and all of which cost real money to discover late.

**Everything is optional.** With an empty `Secrets.xcconfig`, purchases grant a local debug unlock, analytics and attribution no-op, ads stay off, and the app runs end to end. Add a key to switch a service on.

---

## Quick start

```bash
git clone https://github.com/acalise/swiftui-revenuecat-admob-starter.git MyApp
cd MyApp
cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
open AppStarter.xcodeproj
```

Press **⌘R**. Xcode resolves the four Swift packages on first open (a minute or two), then it builds and runs with no accounts, no keys, and no configuration.

Requires **Xcode 16+** and targets **iOS 17+**.

### Make it yours

1. `Configuration/Base.xcconfig` → set `PRODUCT_BUNDLE_IDENTIFIER` and `PRODUCT_NAME`.
2. `AppStarter/DesignSystem/Theme.swift` → change `accent` and `onAccent`.
3. Replace the copy in `OnboardingView` and the benefits in `PaywallView`.
4. Delete `DesignSystemView` and `GrowthView` when you no longer need them.

---

## What's in the box

### Foundation
- **SwiftUI**, iOS 17+, `@Observable` throughout. No `ObservableObject`, no Combine
- **Swift Package Manager** only. No CocoaPods, no `Podfile.lock`, no workspace
- **`.xcconfig`-driven configuration**: keys stay out of source control, and the project file stays out of your diffs
- **File-system synchronized groups** (Xcode 16+), add a `.swift` file and it's in the target. No `project.pbxproj` merge conflicts, ever

### A design system that stays in sync
- **One file, one color.** Change `Theme.accent` and everything updates: buttons, tab bar, onboarding, paywall, both appearances
- `Color(light:dark:)` resolves at draw time, so no view can get stranded in the wrong appearance
- **Light / dark / system** as three real choices, persisted

### Monetisation
- **RevenueCat**: entitlement-based subscriptions, cached for offline, cross-device sync, restore, debug overrides
- **A real paywall** with the four App Review requirements handled and explained
- **Google AdMob**: banner / interstitial / rewarded, automatically suppressed for subscribers

### Growth
- **PostHog**: product analytics, one `track()` call, funnel-ready event naming
- **AppsFlyer**: ad attribution wired to avoid the three silent double-counting and dropped-event traps
- **153 SKAdNetwork IDs** already in `Info.plist` (you cannot add these retroactively without a new submission)
- **App Tracking Transparency**, off by default, with the trade-off documented
- **Rating prompts** timed against Apple's invisible three-per-year cap

### Screens
- 3-step **onboarding** with per-step funnel events and a properly-placed permission ask
- 4 tabs: design system · integration status dashboard · profile layout · settings
- A **Growth tab** that tells you, live, which integrations are actually wired in *this* build, because the failure mode for all of them is silence

---

## Documentation

| | |
|---|---|
| [**Design system**](./docs/design-system.md) | Rebranding; why code over asset catalogs; Dynamic Type |
| [**RevenueCat**](./docs/revenuecat.md) | Why not raw StoreKit 2; setup; the two calls that fail silently; paywall rules |
| [**AppsFlyer**](./docs/appsflyer.md) | Whether you need an MMP at all; SKAdNetwork; the double-counting traps |
| [**PostHog**](./docs/posthog.md) | Event naming that survives six months; replay; feature flags |
| [**AdMob**](./docs/admob.md) | Whether ads are worth it; placement; consent; removal |
| [**Launch checklist**](./docs/launch-checklist.md) | ⚠️ The dashboard settings that silently break attribution. Read before your first campaign. |

Every file in `Services/` also carries a header explaining *why* it's built the way it is. Those headers are the real documentation: the docs above are the setup steps.

---

## Configuration

Everything is driven by `Configuration/Secrets.xcconfig` (gitignored). See [`Secrets.example.xcconfig`](./Configuration/Secrets.example.xcconfig).

| Key | Turns on |
|---|---|
| `REVENUECAT_API_KEY` | Real purchases (otherwise: local debug unlock) |
| `POSTHOG_API_KEY` | Product analytics |
| `APPSFLYER_DEV_KEY` | Ad attribution |
| `ADS_ENABLED = YES` | Ads (Google's test unit IDs are pre-wired) |
| `ATT_ENABLED = YES` | Apple's tracking prompt |

The chain is `Secrets.xcconfig` → build settings → `Info.plist` → `AppConfig.swift`.

> ⚠️ `.xcconfig` keeps a value out of **git**, not out of the **binary**. Anyone can unzip an `.ipa` and read `Info.plist`. Every key above is a *publishable* client key, which is why that's acceptable. Never put a RevenueCat **secret** key or a PostHog **personal** API key there.

Two `.xcconfig` gotchas worth knowing before you edit it:

- **`//` is a comment anywhere on a line**, including mid-value. `https://host` silently becomes `https:`. The file works around this with a `SLASHES = //` variable.
- **A missing build setting leaves the literal `$(FOO)`** in `Info.plist` rather than an empty string. `AppConfig.infoValue` treats a `$(`-prefixed value as absent, which is what keeps a half-configured service cleanly off instead of configured with garbage.

---

## Project structure

```
├── AppStarter.xcodeproj
├── Configuration/
│   ├── Base.xcconfig             # build settings + defaults for every key
│   ├── Secrets.example.xcconfig  # copy to Secrets.xcconfig (gitignored)
│   └── Info.plist                # SKAdNetwork ×153, ATT, AdMob, key passthrough
│
└── AppStarter/
    ├── AppStarterApp.swift       # @main + SDK bootstrap (the ordering matters)
    ├── Config/AppConfig.swift    # every key, read once, typed
    ├── DesignSystem/
    │   ├── Theme.swift           # ← the file you edit to rebrand
    │   └── Components.swift      # Card, buttons, rows, screen scaffold
    ├── Features/
    │   ├── RootView.swift        # onboarding gate + tab bar
    │   ├── DesignSystemView.swift
    │   ├── Onboarding/           # 3-step flow with funnel events
    │   ├── Paywall/              # App Review compliant
    │   ├── Growth/               # live integration status
    │   ├── Profile/              # composed layout + gated feature
    │   └── Settings/
    └── Services/
        ├── Subscriptions.swift   # RevenueCat entitlements (@Observable)
        ├── Analytics.swift       # PostHog + AppsFlyer behind one track()
        ├── Ads.swift             # AdMob, gated on subscription
        ├── Tracking.swift        # ATT
        ├── AppSettings.swift     # persisted preferences
        ├── Notifications.swift   # local notifications
        ├── ReviewPrompt.swift    # rating prompts, timed properly
        └── Haptics.swift         # semantic haptic feedback
```

---

## The bits worth reading

**SDK startup order** (`AppStarterApp.bootstrap()`). AppsFlyer → ATT → AdMob, in that order, for three separate reasons. Get it wrong and you lose install attribution and the higher personalised-ad rate, with nothing in the logs to tell you.

**`#if canImport(...)` everywhere.** Every third-party call is inside a compile-time guard. Remove a package from the project and the code still compiles: the integration just disappears. That's what makes "remove this integration" a three-step operation instead of a refactor.

**`Subscriptions` is `@Observable` and a singleton.** Entitlement state is genuinely global; two views must never disagree about whether the user has paid.

**`AppConfig` treats `$(FOO)` as absent.** See the Configuration section above. It's a two-line check that prevents a whole category of "configured with garbage" bugs.

---

## Common tasks

**Rebrand.** Change `accent` / `onAccent` in `Theme.swift`. ([details](./docs/design-system.md))

**Add a tab.** Add a `Tab(...)` in `MainTabView` and a view file anywhere under `AppStarter/`. Synchronized groups pick it up automatically.

**Gate a feature**
```swift
@Environment(Subscriptions.self) private var subscriptions
if !subscriptions.isPro { UpgradePrompt() }
```

**Track an event.** `Analytics.track("thing_happened", ["where": "settings"])`. Goes to PostHog and AppsFlyer; no-ops if neither is configured.

**Remove an integration.** Each doc ends with an exact removal checklist.

---

## Troubleshooting

**App crashes instantly with `GADInvalidInitializationException`**
`GADApplicationIdentifier` is missing from `Info.plist`. The Google Mobile Ads SDK hard-crashes without it, even if you never show an ad. `Base.xcconfig` supplies Google's sample ID by default, check you didn't blank `ADMOB_APP_ID`.

**A key I set in Secrets.xcconfig has no effect**
Rebuild rather than relaunch, values are baked into `Info.plist` at build time. If it's a URL, check the `//` comment gotcha above.

**Xcode can't find the packages**
File → Packages → Reset Package Caches, then Resolve Package Versions.

**A new Swift file isn't compiling**
It has to live inside `AppStarter/`. Synchronized groups only cover that folder.

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | SwiftUI (iOS 17+, `@Observable`) |
| Dependencies | Swift Package Manager |
| Subscriptions | [RevenueCat](https://www.revenuecat.com) `purchases-ios` |
| Analytics | [PostHog](https://posthog.com) `posthog-ios` |
| Attribution | [AppsFlyer](https://www.appsflyer.com) `AppsFlyerFramework` |
| Ads | [Google AdMob](https://admob.google.com) |
| Storage | `UserDefaults` via `@Observable` |
| Config | `.xcconfig` → `Info.plist` → `AppConfig` |

---

## Contributing

Issues and PRs welcome. Please keep PRs focused, and update the relevant doc when you change behaviour: the explanations are the point of this repo, not a side effect.

## License

MIT. See [LICENSE](./LICENSE).
