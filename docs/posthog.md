# PostHog: product analytics

**File:** `AppStarter/Services/Analytics.swift`
**Config:** `POSTHOG_API_KEY`, `POSTHOG_HOST` in `Configuration/Secrets.xcconfig`
**Cost:** free for 1M events/month. Most small apps never exceed it.

---

## Why use it

AppsFlyer answers *"where did this user come from?"*. PostHog answers *"what did they do once they arrived, and where did they give up?"* Neither substitutes for the other, which is why this starter has both behind one `track()` call.

Concretely, the things you can only see with product analytics:

- **Onboarding drop-off, per step.** "50% finish onboarding" is not actionable. "38% quit on the notifications step" is a fix you can ship this afternoon.
- **Paywall conversion by entry point.** The same paywall converts very differently from a settings tap than from a blocked feature.
- **Retention curves** by cohort, install source, or any property you attach.
- **Session replays**: watch the actual session where someone rage-tapped a button that does nothing.
- **Feature flags** and A/B tests without an app release.

It's open source and self-hostable, which matters if you'd rather not send behavioural data to a vendor.

### Alternatives

| | Notes |
|---|---|
| **PostHog** | Best free tier; replay + flags + analytics in one. What this wires. |
| **Amplitude** | Stronger cohort/funnel analysis. Free tier is smaller. |
| **Mixpanel** | Similar. Cleaner UI, pricier at scale. |
| **Firebase Analytics** | Free and unlimited, but event-parameter limits and a reporting delay make funnel work painful. |
| **None** | Fine for a v1. Add it before you start optimising anything. |

---

## Setup

1. Sign up at [posthog.com](https://posthog.com) (or self-host).
2. Project settings → **Project API key** (starts `phc_`). It's designed to be public, shipping it in the bundle is expected.
3. ```
   // Configuration/Secrets.xcconfig
   POSTHOG_API_KEY = phc_xxxxxxxxxxxx

   // EU projects: the #1 cause of "events aren't arriving".
   // Note the SLASHES trick: xcconfig treats `//` as a comment mid-value.
   POSTHOG_SLASHES = //
   POSTHOG_HOST = https:$(POSTHOG_SLASHES)eu.i.posthog.com
   ```
4. Rebuild (⌘R). Values are baked into Info.plist at build time.

**Verify:** Growth tab → *Send a test event* → PostHog → Activity. Should appear within seconds.

---

## Using it

```swift
Analytics.track("feature_used", ["feature": "export", "duration_ms": 1240])
Analytics.screen("Settings")
Analytics.identify(user.id, ["email": user.email, "plan": "pro"])  // after login
Analytics.resetUser()                                              // on logout
```

`track()` also forwards to AppsFlyer. If you remove AppsFlyer, `track()` keeps working unchanged.

### Naming events

Pick a convention and hold it. This starter uses `object_action`, lowercase snake_case:

```
onboarding_step        paywall_dismissed      purchase_completed
reminder_toggled       att_prompt_answered    review_prompt_requested
```

Six months in, the difference between a usable event list and an unusable one is entirely naming discipline. Prefer few events with rich properties over many narrowly-named events, `paywall_dismissed { source: 'settings' }` beats `settings_paywall_dismissed`, because you can group by source *and* see the total.

### Super properties

`Analytics.start()` registers `platform: "ios"` on every event:

```swift
PostHogSDK.shared.register(["platform": "ios"])
```

If several apps report into one PostHog project, add an `app` discriminator here. Without it, two apps that both emit `onboarding_step` produce one meaningless merged funnel.

---

## Automatic screen tracking

PostHog can capture SwiftUI screen views for you:

```swift
config.captureScreenViews = true
```

Off by default here, deliberately. SwiftUI autocapture produces view *type* names (`ScreenScrollView<TupleView<…>>`) rather than the screen names you'd want in a funnel. Explicit `Analytics.screen("Paywall")` calls at the handful of screens that matter give you far cleaner data. Turn it on if you'd rather have everything and filter later.

## Session replay

```swift
config.sessionReplay = true
```

Genuinely useful for diagnosing "users say it's confusing": you watch it happen. Two caveats: it consumes event quota fast, and it captures the screen, so **mask anything sensitive** with `<PostHogMaskView>` before enabling it in production. Check your privacy policy covers it.

## Feature flags

```swift
if PostHogSDK.shared.isFeatureEnabled("new-paywall") {
    NewPaywallView()
} else {
    PaywallView()
}
```

Ship both code paths, flip the flag from the dashboard, no release. The natural pairing with `PaywallView`, paywall variants are the highest-leverage thing to A/B test in a subscription app.

---

## What not to send

`EXPO_PUBLIC_POSTHOG_KEY` is a write-only ingestion key, publishing it is fine. What is **not** fine:

- A **personal API key** (`phx_…`). Those can read and delete your data. Server-side only. Note that `.xcconfig` keeps a value out of *git*, not out of the *binary*, anyone can unzip an `.ipa` and read Info.plist.
- Personally identifying data in event properties. `Analytics.identify(user.id)` links a user; putting an email in every event's properties spreads PII across your whole dataset and makes a deletion request much harder to honour.
- Anything you'd be uncomfortable seeing in a support screenshot.

---

## Removing PostHog

1. In Xcode: select the project → **AppStarter** target → *Frameworks, Libraries, and Embedded Content* → remove **PostHog**.
2. Project → *Package Dependencies* → remove `posthog-ios`.
3. Delete `POSTHOG_API_KEY` / `POSTHOG_HOST` from `Secrets.xcconfig` and `Info.plist`, and the matching properties in `AppConfig.swift`.

You do **not** need to touch `Analytics.swift` or any call site: every PostHog block is inside `#if canImport(PostHog)`, so removing the package compiles them out. `Analytics.track()` keeps working and simply stops forwarding to PostHog. That's the whole reason for the `canImport` guards.
