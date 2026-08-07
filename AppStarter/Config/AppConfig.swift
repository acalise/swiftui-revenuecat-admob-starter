import Foundation

/// Every third-party key the app reads, in one place.
///
/// ## Where the values come from
/// `Secrets.xcconfig` → build settings → `Info.plist` → here. That chain exists
/// so keys stay out of source control (`Secrets.xcconfig` is gitignored) while
/// still being available synchronously at launch, with no network call and no
/// `try!`.
///
/// ## What belongs here, and what absolutely does not
/// Everything below is a **publishable client key**: RevenueCat SDK keys, the
/// AppsFlyer dev key, PostHog project keys, AdMob unit IDs. Every one of those
/// vendors documents them as client-side values, and they ship inside the app
/// binary where anyone can read them.
///
/// A RevenueCat *secret* key, a PostHog *personal* API key, or anything that can
/// write on your behalf must never appear here. Those belong on a server. Note
/// that `.xcconfig` only keeps a value out of *git*: it does not keep it out of
/// the app bundle. Anyone can unzip an `.ipa` and read `Info.plist`.
///
/// ## Nothing here is required
/// Every service derives an `isEnabled` flag from whether its key is present,
/// and no-ops when it isn't. A fresh clone builds and runs with an empty
/// `Secrets.xcconfig`: purchases grant a local debug unlock, analytics and
/// attribution do nothing, ads stay off.
enum AppConfig {

    // MARK: - App

    /// Numeric Apple App ID: the digits in your App Store URL (`…/id1234567890`).
    /// Needed by AppsFlyer for SKAdNetwork, and by the "write a review" deep link.
    static let appleAppID = infoValue("APPLE_APP_ID")

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - RevenueCat

    /// Public SDK key (`appl_…`). Blank in a fresh clone.
    static let revenueCatKey = infoValue("REVENUECAT_API_KEY")
    static var revenueCatEnabled: Bool { !revenueCatKey.isEmpty }

    /// Entitlement identifier, exactly as spelled in the RevenueCat dashboard.
    static let entitlementID = infoValue("RC_ENTITLEMENT", default: "pro")

    /// Offering identifier, or empty to use whichever offering RevenueCat marks
    /// as current, which is what you want, since it lets you change pricing
    /// without shipping an app update.
    static let offeringID = infoValue("RC_OFFERING")

    // MARK: - AppsFlyer

    static let appsFlyerDevKey = infoValue("APPSFLYER_DEV_KEY")
    static var appsFlyerEnabled: Bool { !appsFlyerDevKey.isEmpty }

    // MARK: - PostHog

    static let postHogKey = infoValue("POSTHOG_API_KEY")
    static let postHogHost = infoValue("POSTHOG_HOST", default: "https://us.i.posthog.com")
    static var postHogEnabled: Bool { !postHogKey.isEmpty }

    // MARK: - Ads

    /// Ads are opt-in even when the SDK is linked: most apps show them to free
    /// users only, and you almost never want them while building.
    static let adsEnabled = infoValue("ADS_ENABLED") == "YES"

    /// Google's official *test* ad unit IDs, so ads work with no AdMob account.
    ///
    /// Serving real ads against your own unit IDs in development is what Google
    /// calls invalid traffic, and it gets accounts banned, not warned, banned,
    /// with unpaid earnings forfeited. Keep these until you ship.
    enum AdUnit {
        static let banner = infoValue("ADMOB_BANNER_UNIT_ID",
                                      default: "ca-app-pub-3940256099942544/2934735716")
        static let interstitial = infoValue("ADMOB_INTERSTITIAL_UNIT_ID",
                                            default: "ca-app-pub-3940256099942544/4411468910")
        static let rewarded = infoValue("ADMOB_REWARDED_UNIT_ID",
                                        default: "ca-app-pub-3940256099942544/1712485313")
    }

    // MARK: - App Tracking Transparency

    /// Whether to show Apple's ATT prompt.
    ///
    /// Leaving this off does **not** break attribution: AppsFlyer, SKAdNetwork
    /// and RevenueCat all work without IDFA. What you lose is device-level
    /// matching for the minority who would have said yes. See `Tracking.swift`.
    static let attEnabled = infoValue("ATT_ENABLED") == "YES"

    // MARK: - Legal (App Review requires working URLs)

    static let termsURL = URL(string: infoValue("TERMS_URL", default: "https://example.com/terms"))!
    static let privacyURL = URL(string: infoValue("PRIVACY_URL", default: "https://example.com/privacy"))!

    // MARK: - Info.plist lookup

    /// Reads a string from `Info.plist`, treating an unsubstituted xcconfig
    /// placeholder as absent.
    ///
    /// The `$(FOO)` check matters: if a build setting isn't defined, Xcode
    /// leaves the literal `$(FOO)` in the plist rather than an empty string. Miss
    /// that and `revenueCatEnabled` reports `true` for the string `"$(REVENUECAT_API_KEY)"`,
    /// and RevenueCat gets configured with garbage instead of cleanly no-opping.
    private static func infoValue(_ key: String, default fallback: String = "") -> String {
        guard let raw = Bundle.main.infoDictionary?[key] as? String else { return fallback }
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.isEmpty || value.hasPrefix("$(") { return fallback }
        return value
    }
}
