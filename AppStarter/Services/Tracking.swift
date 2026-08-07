import AppTrackingTransparency
import Foundation

/// Apple's App Tracking Transparency prompt.
///
/// ## What it actually controls
/// ATT gates exactly one thing: access to the IDFA, the device advertising
/// identifier. It does **not** gate AppsFlyer, PostHog, RevenueCat, SKAdNetwork,
/// or your ability to run ads. All of those work with the prompt denied, or
/// never shown at all.
///
/// What a "yes" buys: deterministic, user-level ad attribution, *this exact
/// install* came from *that exact ad*. What a "no" (or never asking) leaves you:
/// SKAdNetwork's privacy-preserving aggregate attribution plus AppsFlyer's
/// probabilistic matching. Enough to optimise campaigns; not enough to reconcile
/// individual users.
///
/// ## Should you show it?
/// Only if you spend on ads. Opt-in rates run roughly 20–40%, and the prompt
/// costs a beat of user attention and a little trust on first launch. With no
/// paid acquisition it buys you nothing, leave `ATT_ENABLED = NO` and it never
/// appears.
///
/// ## If you do show it, show it EARLY
/// AppsFlyer holds its install postback for up to 60 seconds waiting on the ATT
/// decision (see `Analytics.start()`). Prompt after onboarding and a paywall and
/// you routinely exceed that window: the postback fires without the IDFA and the
/// "yes" you worked for is wasted.
///
/// ## App Review
/// `NSUserTrackingUsageDescription` must be in Info.plist and must describe a
/// real benefit **to the user**. Generic wording is a common rejection. You may
/// show a *pre-prompt* explaining why you're asking, but it must not imitate
/// Apple's dialog and must not offer any incentive for saying yes.
@MainActor
enum Tracking {

    /// Request tracking permission if it hasn't been decided yet.
    ///
    /// No-ops when `ATT_ENABLED` is off and when the user has already answered,
    /// iOS only ever shows this prompt once per install, so re-asking is
    /// impossible by design.
    ///
    /// - Important: iOS silently discards the request if the app is not yet
    ///   foregrounded and active, which is why `AppStarterApp` calls this after
    ///   the first scene becomes active rather than at launch.
    @discardableResult
    static func requestPermissionIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard AppConfig.attEnabled else { return .notDetermined }

        let current = ATTrackingManager.trackingAuthorizationStatus
        guard current == .notDetermined else { return current }

        let status = await ATTrackingManager.requestTrackingAuthorization()
        // Worth tracking: the opt-in rate is the number that tells you whether
        // your pre-prompt copy is doing anything.
        Analytics.track("att_prompt_answered", ["status": status.label])
        return status
    }

    /// Current status, without prompting.
    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }
}

extension ATTrackingManager.AuthorizationStatus {
    var label: String {
        switch self {
        case .authorized: "authorized"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not_determined"
        @unknown default: "unknown"
        }
    }
}
