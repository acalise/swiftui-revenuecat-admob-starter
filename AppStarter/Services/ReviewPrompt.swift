import StoreKit
import SwiftUI

/// Asking for a rating, at a moment that earns a good one.
///
/// ## Why bother
/// Star rating is one of the strongest conversion levers on a store listing: it
/// sits under your icon in every search result. It's also mostly a function of
/// *when* you ask. Ask during a frustrating moment and you harvest the one-stars
/// that would otherwise never have been written.
///
/// ## The rules Apple imposes whether you know them or not
/// The system prompt is capped at **three per user per 365 days**, silently. Over
/// the cap, the request returns normally and nothing appears. You cannot detect
/// this, you cannot learn whether the user rated, and you must not gate anything
/// on it or reward it. "Review gating", asking how they feel first and only
/// prompting the happy ones: is explicitly banned (guideline 1.1.7).
///
/// Because the budget is small and invisible, spend it deliberately. This type
/// adds the two conditions Apple doesn't: a minimum number of positive moments
/// before the first ask, and a cooldown between asks.
///
/// ## Where to call it
/// Right after something went **well**: a task finished, a streak extended, a
/// result exported. Never after an error, never during onboarding, never on
/// launch, and never on the same screen as a paywall.
@MainActor
enum ReviewPrompt {

    private static let momentsKey = "review.positiveMoments"
    private static let lastPromptKey = "review.lastPromptAt"

    /// Positive moments required before the first prompt.
    private static let minimumMoments = 5
    /// Days between prompts. Apple allows 3/year; this spaces them out.
    private static let cooldownDays: TimeInterval = 120

    /// Record that something good just happened, and prompt if the thresholds
    /// are met. Safe to call liberally: it counts, checks, and usually does
    /// nothing.
    static func recordPositiveMoment(weight: Int = 1) {
        let defaults = UserDefaults.standard
        let moments = defaults.integer(forKey: momentsKey) + weight
        defaults.set(moments, forKey: momentsKey)

        guard moments >= minimumMoments else { return }

        let last = defaults.double(forKey: lastPromptKey)
        let elapsed = Date().timeIntervalSince1970 - last
        guard last == 0 || elapsed > cooldownDays * 86_400 else { return }

        request()
    }

    /// Show the rating sheet now, bypassing the thresholds.
    ///
    /// Fine for an explicit "Rate this app" row in Settings, but remember that
    /// a user over Apple's yearly cap will see nothing at all, so `openStorePage()`
    /// is the honest target for a deliberate tap.
    static func request() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
        // PostHog can't observe the sheet, but it can tell you how many users
        // reached the moment you deemed prompt-worthy.
        Analytics.track("review_prompt_requested")
        AppStore.requestReview(in: scene)
    }

    /// Open the App Store's write-a-review page directly.
    ///
    /// Unlike the system sheet this always does something visible, which makes
    /// it the right target for a Settings row. It leaves your app, which is why
    /// it's wrong for an automatic prompt.
    static func openStorePage() {
        guard !AppConfig.appleAppID.isEmpty,
              let url = URL(string: "https://apps.apple.com/app/id\(AppConfig.appleAppID)?action=write-review")
        else { return }
        UIApplication.shared.open(url)
    }

    /// Debug helper, clear the counters so you can exercise the flow again.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: momentsKey)
        UserDefaults.standard.removeObject(forKey: lastPromptKey)
    }
}
