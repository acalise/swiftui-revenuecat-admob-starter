import Foundation

#if canImport(PostHog)
import PostHog
#endif
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

/// Two providers behind one `track()` call.
///
///   PostHog   → product analytics. "Where do people drop out of onboarding?"
///   AppsFlyer → ad attribution.    "Which ad did this paying user come from?"
///
/// They answer different questions and neither replaces the other, which is why
/// both are here. PostHog can't tell you a user came from a TikTok ad. AppsFlyer
/// can't tell you they abandoned onboarding on step 2.
///
/// Both no-op when unconfigured, so call sites never guard.
///
/// ---
/// ## Three non-obvious things this file exists to get right
/// Each has cost a real app real money. None of them produce an error message.
///
/// **1. `appsFlyerID` feeds `Purchases.shared.attribution.setAppsflyerID()`** in
/// `Subscriptions.swift`. RevenueCat keys every server-side event it forwards to
/// AppsFlyer (`af_start_trial` / `af_purchase`) on the `$appsflyerId` subscriber
/// attribute. Leave it unset and RevenueCat drops all of them silently, while
/// the dashboard integration still reads "Active". Installs keep attributing
/// (that's AppsFlyer's own SDK), which is exactly what hides the gap: the funnel
/// looks alive right up to the revenue events that matter.
///
/// **2. `af_app_opened` fires on every launch.** Meta's AppsFlyer integration has
/// no install postback, mapped in-app events are its only inbound signal, and
/// `af_app_opened` → `fb_mobile_activate_app` is the one that fires for every
/// user. Without it, Meta's "Last iOS Install" goes stale and app-install
/// campaigns fail validation with error `#1815437`, whose message
/// ("application_id needs to be valid") points at entirely the wrong thing.
/// TikTok maps the same event to LaunchAPP.
///
/// **3. Revenue events are NOT sent to AppsFlyer from here**: RevenueCat sends
/// the server-verified copy. AppsFlyer does not de-duplicate SDK events against
/// server-to-server events, so logging both doubles every purchase and its
/// revenue, which halves your apparent cost-per-paying-user: the exact number
/// you scale ad spend on. See `rcForwardedEvents` below.
///
/// The dashboard-side half of all this, toggles no amount of correct code can
/// substitute for: is `docs/launch-checklist.md`. Read it before your first
/// campaign, not after.
@MainActor
enum Analytics {

    // MARK: - Standard event names

    /// AppsFlyer's standard event vocabulary, which Meta and TikTok recognise
    /// natively. Using these names means the ad networks can optimise toward
    /// them with no custom mapping on your side. Rename them and you inherit a
    /// mapping chore in three dashboards.
    ///
    /// Product-analytics-only events (`paywall_dismissed`, …) don't belong here
    ///, pass any string to `track()`.
    enum Event {
        /// Onboarding finished. Meta reads this as activation.
        static let tutorialCompletion = "af_tutorial_completion"
        static let completeRegistration = "af_complete_registration"
        /// Paywall shown.
        static let contentView = "af_content_view"
        /// Subscribe tapped, intent, not yet money.
        static let initiatedCheckout = "af_initiated_checkout"
        /// The store granted a free trial.
        static let startTrial = "af_start_trial"
        /// A paid subscription began with no trial.
        static let subscribe = "af_subscribe"
        /// Any completed purchase.
        static let purchase = "af_purchase"
    }

    /// Events RevenueCat forwards server-side. `track()` still sends these to
    /// PostHog: it just refuses to double-report them to AppsFlyer. See note 3.
    private static let rcForwardedEvents: Set<String> = [
        Event.startTrial, Event.subscribe, Event.purchase,
    ]

    // MARK: - Lifecycle

    private static var didStart = false

    /// Start both SDKs. Called once, from `AppStarterApp`.
    ///
    /// PostHog is configured here rather than lazily because its client queues
    /// events until it's ready, anything captured during the first frame is
    /// kept rather than dropped.
    static func start() {
        guard !didStart else { return }
        didStart = true

        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            let config = PostHogConfig(apiKey: AppConfig.postHogKey, host: AppConfig.postHogHost)
            // Application Opened / Backgrounded / Installed, so you get retention
            // curves without instrumenting anything yourself.
            config.captureApplicationLifecycleEvents = true
            // Screen views are sent explicitly via `screen(_:)`. SwiftUI
            // autocapture produces view-type names rather than the screen names
            // you'd actually want in a funnel.
            config.captureScreenViews = false
            PostHogSDK.shared.setup(config)
            // Super-property on every event. If several apps report into one
            // PostHog project, add an `app` discriminator here, without it, two
            // apps that both emit `onboarding_step` produce one meaningless
            // merged funnel.
            PostHogSDK.shared.register(["platform": "ios"])
        }
        #endif

        #if canImport(AppsFlyerLib)
        if AppConfig.appsFlyerEnabled {
            let af = AppsFlyerLib.shared()
            // AppsFlyer 7 replaced the old `appsFlyerDevKey` / `appleAppID`
            // property assignments with this initializer: those properties are
            // now read-only. Must be called before `start()`.
            af.initialize(devKey: AppConfig.appsFlyerDevKey, appId: AppConfig.appleAppID)
            #if DEBUG
            af.isDebug = true
            #endif
            // Hold the install postback for up to 60s waiting on the ATT
            // decision, so a user who grants tracking still gets full IDFA-level
            // attribution.
            //
            // This only pays off if you prompt EARLY. Prompt after onboarding
            // and a paywall and you'll routinely blow past 60s: the postback
            // fires without IDFA and the "yes" you worked for is wasted.
            // SKAdNetwork and the AppsFlyer ID are unaffected either way.
            af.waitForATTUserAuthorization(timeoutInterval: AppConfig.attEnabled ? 60 : 0)
            af.start()

            // See note 2: this single line is Meta's entire install signal.
            // Logged directly rather than through track(), since PostHog already
            // captures Application Opened natively and we don't want it twice.
            af.logEvent(name: "af_app_opened", values: nil)
        }
        #endif
    }

    // MARK: - Tracking

    /// Fire-and-forget event capture, fanned out to both providers.
    static func track(_ event: String, _ properties: [String: Any] = [:]) {
        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            PostHogSDK.shared.capture(event, properties: properties)
        }
        #endif

        guard !rcForwardedEvents.contains(event) else { return } // note 3

        #if canImport(AppsFlyerLib)
        if AppConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().logEvent(name: event, values: properties)
        }
        #endif

        #if DEBUG
        if !AppConfig.postHogEnabled && !AppConfig.appsFlyerEnabled {
            print("[analytics] (no-op) \(event) \(properties)")
        }
        #endif
    }

    /// Manual screen view.
    static func screen(_ name: String, _ properties: [String: Any] = [:]) {
        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            PostHogSDK.shared.screen(name, properties: properties)
        }
        #endif
    }

    /// Tie events to a stable user id (your auth id, not a device id).
    /// Call after login, and call `resetUser()` on logout, or the next account
    /// inherits the previous one's history.
    static func identify(_ userID: String, _ traits: [String: Any] = [:]) {
        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            PostHogSDK.shared.identify(userID, userProperties: traits)
        }
        #endif
        #if canImport(AppsFlyerLib)
        if AppConfig.appsFlyerEnabled {
            AppsFlyerLib.shared().customerUserID = userID
        }
        #endif
    }

    /// Forget the current user. Call on logout.
    static func resetUser() {
        #if canImport(PostHog)
        if AppConfig.postHogEnabled { PostHogSDK.shared.reset() }
        #endif
    }

    // MARK: - AppsFlyer ID

    /// AppsFlyer's device id for this install, or `nil` when AppsFlyer is off.
    ///
    /// Consumed by `Purchases.shared.attribution.setAppsflyerID()` in
    /// `Subscriptions.swift`, see note 1.
    static var appsFlyerID: String? {
        #if canImport(AppsFlyerLib)
        guard AppConfig.appsFlyerEnabled else { return nil }
        let id = AppsFlyerLib.shared().getAppsFlyerUID()
        return id.isEmpty ? nil : id
        #else
        return nil
        #endif
    }

    // MARK: - SKAdNetwork conversion events

    /// On-device twins of RevenueCat's server-side trial/purchase events.
    ///
    /// SKAdNetwork conversion values can only be set by the on-device SDK, at the
    /// moment *it* logs an event. RevenueCat's server-side events can never
    /// touch them. Without these, every SKAN postback your app produces says
    /// "install" and nothing more, so iOS campaigns on TikTok and Meta have no
    /// signal to optimise toward trials or purchases.
    ///
    /// The names are deliberately distinct from the standard ones: AppsFlyer
    /// does not de-duplicate SDK events against server-to-server events, so
    /// reusing `af_purchase` here would double-count every purchase (note 3).
    /// Map `af_skan_*` **only** in SKAN Conversion Studio's schema, never in a
    /// partner postback mapping.
    static func logSKANConversion(_ name: SKANEvent, revenue: Double? = nil, currency: String = "USD") {
        #if canImport(AppsFlyerLib)
        guard AppConfig.appsFlyerEnabled else { return }
        var values: [String: Any] = [:]
        if let revenue {
            values["af_revenue"] = revenue
            values["af_currency"] = currency
        }
        AppsFlyerLib.shared().logEvent(name: name.rawValue, values: values)
        #endif
    }

    enum SKANEvent: String {
        case trial = "af_skan_trial"
        case purchase = "af_skan_purchase"
    }

    // MARK: - Revenue helpers

    /// Records a started free trial.
    ///
    /// Lands in PostHog only; AppsFlyer receives RevenueCat's server-verified
    /// copy. The `af_revenue` / `af_currency` shape is kept anyway so PostHog
    /// funnels stay directly comparable with the AppsFlyer numbers.
    ///
    /// - Parameter amount: what the plan costs *after* the trial.
    static func trackTrialStart(amount: Double, currency: String, productID: String, plan: String) {
        track(Event.startTrial, [
            "af_revenue": 0, // the trial is free; `will_convert_to` is what it becomes
            "af_currency": currency,
            "af_content_id": productID,
            "plan": plan,
            "will_convert_to": amount,
        ])
        logSKANConversion(.trial)
        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            PostHogSDK.shared.capture("purchase_completed", properties: ["plan": plan, "is_trial": true])
        }
        #endif
    }

    /// Records a paid purchase.
    static func trackPurchase(amount: Double, currency: String, productID: String, plan: String) {
        let props: [String: Any] = [
            "af_revenue": amount,
            "af_currency": currency,
            "af_content_id": productID,
            "plan": plan,
        ]
        track(Event.subscribe, props)
        // Also log af_purchase: some networks optimise on that name specifically.
        track(Event.purchase, props)
        logSKANConversion(.purchase, revenue: amount, currency: currency)
        #if canImport(PostHog)
        if AppConfig.postHogEnabled {
            PostHogSDK.shared.capture("purchase_completed", properties: ["plan": plan, "is_trial": false])
        }
        #endif
    }
}
