import SwiftUI

/// App entry point and SDK bootstrap.
///
/// The interesting part is `bootstrap()`: the ordering there is not arbitrary.
@main
struct AppStarterApp: App {
    @State private var settings = AppSettings.shared
    @State private var subscriptions = Subscriptions.shared

    /// Set once the first scene is active, which is the earliest moment iOS will
    /// actually present the ATT prompt. Requesting before this point is a no-op
    /// that consumes your one chance to ask.
    @State private var didBootstrap = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(subscriptions)
                // A single explicit preference drives the whole app. Applying it
                // at the root means sheets and fullScreenCovers inherit it too,
                // which they don't if you scatter `.preferredColorScheme` per
                // screen, and a light-mode modal over a dark app is jarring.
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.accent)
                .task {
                    guard !didBootstrap else { return }
                    didBootstrap = true
                    await bootstrap()
                }
        }
    }

    /// Start the third-party SDKs, in the one order that works.
    ///
    /// 1. **AppsFlyer first**, and not awaited for its result. Its `start()` is
    ///    what opens the up-to-60s window during which it holds the install
    ///    postback waiting on the ATT answer. Start it *after* the prompt and
    ///    there's no window left to wait in, so a granted IDFA arrives too late
    ///    to attach to the install.
    ///
    /// 2. **The ATT prompt second.** iOS silently discards the request unless the
    ///    app is foregrounded and active, which is why this runs from a `.task`
    ///    on the root view rather than in an initialiser.
    ///
    /// 3. **AdMob last**, after the ATT decision. The Mobile Ads SDK reads the
    ///    tracking status when it initialises to decide whether it may request
    ///    personalised ads. Initialise before the answer exists and you're locked
    ///    into non-personalised (lower-paying) ads for the whole session.
    ///
    /// RevenueCat is independent of that chain, but it wants AppsFlyer's device
    /// id (see `Analytics.swift` note 1), so it runs after step 1.
    private func bootstrap() async {
        Analytics.start()                        // (1)
        await Tracking.requestPermissionIfNeeded() // (2), no-ops unless ATT_ENABLED
        await Ads.start()                        // (3), no-ops unless ADS_ENABLED

        await subscriptions.start()
        Haptics.prepare()
        Analytics.screen("app_open")
    }
}
