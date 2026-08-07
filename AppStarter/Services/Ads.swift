import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Google AdMob, optional and off by default.
///
/// ## Should you even use ads?
/// For most consumer apps a subscriber is worth 10–100× an ad-supported user.
/// Ads make sense when you have real volume, when nobody will pay for the use
/// case, or: most commonly, as the free tier beneath a subscription. That last
/// shape is what's wired here: `canServeAds` is false for subscribers, so the
/// paywall gets a genuine benefit to sell ("remove ads") at no extra work.
///
/// If you're not shipping ads, `docs/admob.md` has the removal steps.
///
/// ## What's already handled
/// Google's official **test** ad unit IDs are wired in, so ads work immediately
/// without an AdMob account. Serving real ads against your own live unit IDs in
/// development is what Google calls invalid traffic, and it gets accounts banned
///, not warned, banned, with unpaid earnings forfeited. Keep the test IDs until
/// you ship.
@MainActor
enum Ads {

    /// The single question every ad site should ask.
    ///
    /// Ads off, SDK missing, or the user pays: all one answer. Keeping the
    /// subscriber check here rather than at each call site is what stops the one
    /// banner someone forgot to gate from appearing in a paying customer's
    /// screenshot.
    static var canServeAds: Bool {
        #if canImport(GoogleMobileAds)
        return AppConfig.adsEnabled && !Subscriptions.shared.isPro
        #else
        return false
        #endif
    }

    private static var didStart = false

    /// Start the Mobile Ads SDK.
    ///
    /// Call this **after** the ATT decision. The SDK reads the tracking status
    /// when it initialises to decide whether it may request personalised ads;
    /// start it first and you're locked into non-personalised (lower-paying) ads
    /// for the whole session. `AppStarterApp` gets this ordering right.
    static func start() async {
        #if canImport(GoogleMobileAds)
        guard AppConfig.adsEnabled, !didStart else { return }
        didStart = true
        await MobileAds.shared.start()
        #endif
    }

    // MARK: - Interstitials

    #if canImport(GoogleMobileAds)
    private static var interstitial: InterstitialAd?
    private static var interstitialDelegate: FullScreenDelegate?
    #endif

    /// Pre-load an interstitial so it can appear instantly later.
    ///
    /// Interstitials take seconds to fetch. Requesting one at the moment you
    /// want to show it means either a frozen UI or an ad that never appears, so
    /// load ahead of the moment you plan to use it.
    static func preloadInterstitial() async {
        #if canImport(GoogleMobileAds)
        guard canServeAds else { return }
        interstitial = try? await InterstitialAd.load(
            with: AppConfig.AdUnit.interstitial,
            request: Request()
        )
        #endif
    }

    /// Show the pre-loaded interstitial, and warm the next one.
    /// Returns whether an ad was actually shown.
    ///
    /// Be sparing. Interstitials at a natural pause (task saved, level complete)
    /// are tolerated; on app open or mid-task they are a leading cause of
    /// one-star reviews, and Apple rejects ads shown before the user has done
    /// anything. Never show one during onboarding.
    @discardableResult
    static func showInterstitial() async -> Bool {
        #if canImport(GoogleMobileAds)
        guard canServeAds else { return false }
        if interstitial == nil { await preloadInterstitial() }
        guard let ad = interstitial, let root = rootViewController else { return false }

        let delegate = FullScreenDelegate {
            interstitial = nil
            Task { await preloadInterstitial() }
        }
        interstitialDelegate = delegate
        ad.fullScreenContentDelegate = delegate
        ad.present(from: root)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Rewarded

    /// Show a rewarded ad; returns true **only** if the user earned the reward.
    ///
    /// The highest-value format and the only one users generally like, because
    /// it's an explicit trade. Grant the reward on the earned callback alone: a
    /// user who closes the ad early has not earned it, and dismissal fires either
    /// way.
    static func showRewarded() async -> Bool {
        #if canImport(GoogleMobileAds)
        guard canServeAds, let root = rootViewController else { return false }
        guard let ad = try? await RewardedAd.load(
            with: AppConfig.AdUnit.rewarded,
            request: Request()
        ) else { return false }

        return await withCheckedContinuation { continuation in
            var earned = false
            let delegate = FullScreenDelegate {
                continuation.resume(returning: earned)
            }
            rewardedDelegate = delegate
            ad.fullScreenContentDelegate = delegate
            ad.present(from: root) { earned = true }
        }
        #else
        return false
        #endif
    }

    #if canImport(GoogleMobileAds)
    private static var rewardedDelegate: FullScreenDelegate?

    /// Bridges AdMob's delegate callbacks to a closure. Retained above, because
    /// `fullScreenContentDelegate` is weak, let it deallocate and the dismissal
    /// callback never fires, which leaves `showRewarded`'s continuation hanging
    /// forever.
    private final class FullScreenDelegate: NSObject, FullScreenContentDelegate {
        private let onFinish: () -> Void
        private var didFinish = false

        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { finish() }

        func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
            finish()
        }

        /// A continuation resumed twice is a crash, so guard against both
        /// callbacks arriving.
        private func finish() {
            guard !didFinish else { return }
            didFinish = true
            onFinish()
        }
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
    #endif
}

// MARK: - Banner

/// An AdMob banner that's safe to leave in your layout.
///
/// Renders nothing when ads are off, when the SDK isn't linked, when the user
/// subscribes, or when an ad fails to fill. Because it collapses to zero height
/// rather than reserving space, you can drop `BannerAdView()` into a screen and
/// forget about it: the layout is identical for paying users.
struct BannerAdView: View {
    @State private var failed = false

    var body: some View {
        #if canImport(GoogleMobileAds)
        if Ads.canServeAds && !failed {
            BannerRepresentable(onFailure: { failed = true })
                // The standard banner height. Adaptive banners return a
                // device-dependent height; look it up if you switch formats.
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
        #else
        // Explicit, because a `body` whose entire contents are compiled out
        // fails to build ("missing return"). This branch is what lets you drop
        // the GoogleMobileAds package without touching any call site.
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct BannerRepresentable: UIViewRepresentable {
    let onFailure: () -> Void

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = AppConfig.AdUnit.banner
        view.rootViewController = context.coordinator.rootViewController
        view.delegate = context.coordinator
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure) }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let onFailure: () -> Void
        init(onFailure: @escaping () -> Void) { self.onFailure = onFailure }

        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow }?
                .rootViewController
        }

        /// No-fill is normal, low traffic, some regions, test IDs under load.
        /// Collapse rather than leaving a grey rectangle.
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onFailure()
        }
    }
}
#endif
