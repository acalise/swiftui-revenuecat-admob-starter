import SwiftUI

/// A live dashboard for the four growth integrations.
///
/// Every row tells you whether that service is actually wired up in *this*
/// build, and gives you a button to exercise it. That's more useful than it
/// sounds: the failure mode for all four is silence. A missing RevenueCat key,
/// an SDK that isn't linked, a PostHog host typo, none of them throw. They
/// quietly do nothing while you assume they work, and you find out three weeks
/// into an ad campaign.
///
/// Delete this screen before shipping, or gate it behind `#if DEBUG`.
struct GrowthView: View {
    @Environment(Subscriptions.self) private var subscriptions

    @State private var showPaywall = false
    @State private var appsFlyerID: String?
    @State private var isWorking = false
    @State private var alert: AlertContent?

    var body: some View {
        ScreenScrollView(title: "Growth", subtitle: "Wiring status for every optional integration") {
            subscriptionsSection
            analyticsSection
            attributionSection
            adsSection
            ratingsSection
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message)) }
    }

    // MARK: - RevenueCat

    private var subscriptionsSection: some View {
        Group {
            SectionLabel("RevenueCat · subscriptions")
            Card {
                StatusRow(
                    label: "SDK key",
                    isOn: AppConfig.revenueCatEnabled,
                    onText: "configured",
                    offText: "not set, debug unlock only"
                )
                StatusRow(
                    label: "Entitlement",
                    isOn: subscriptions.isPro,
                    onText: "active",
                    offText: "inactive"
                )
                StatusRow(
                    label: "Plans loaded",
                    isOn: !subscriptions.plans.isEmpty,
                    onText: "\(subscriptions.plans.count)",
                    offText: "none"
                )
                Divider().background(Theme.separator)
                HStack(spacing: 10) {
                    Button("Open paywall") {
                        Haptics.tap()
                        showPaywall = true
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Restore") {
                        run {
                            let result = await subscriptions.restore()
                            if case .failure(let message) = result {
                                alert = AlertContent(title: "Nothing restored", message: message)
                            } else {
                                alert = AlertContent(title: "Restored", message: "Your subscription is active.")
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - PostHog

    private var analyticsSection: some View {
        Group {
            SectionLabel("PostHog · product analytics")
            Card {
                StatusRow(
                    label: "Project key",
                    isOn: AppConfig.postHogEnabled,
                    onText: "configured",
                    offText: "not set, track() no-ops"
                )
                Text("Events appear in PostHog → Activity within a few seconds. If nothing shows up, check the host region. EU projects need eu.i.posthog.com.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)

                Button("Send a test event") {
                    Haptics.tapLight()
                    Analytics.track("debug_test_event", ["source": "growth_screen"])
                    alert = AlertContent(
                        title: "Event sent",
                        message: AppConfig.postHogEnabled
                            ? "Look for \"debug_test_event\" in PostHog → Activity."
: "No PostHog key set, so this went nowhere. That's the point of the row above."
                    )
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - AppsFlyer

    private var attributionSection: some View {
        Group {
            SectionLabel("AppsFlyer · ad attribution")
            Card {
                StatusRow(
                    label: "Dev key",
                    isOn: AppConfig.appsFlyerEnabled,
                    onText: "configured",
                    offText: "not set, attribution off"
                )
                StatusRow(
                    label: "AppsFlyer ID",
                    isOn: appsFlyerID != nil,
                    onText: appsFlyerID ?? "",
                    offText: "tap below to fetch"
                )
                Text("This ID is what RevenueCat attaches to every revenue event it forwards. If it never resolves, RevenueCat silently drops those events, see docs/launch-checklist.md.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)

                Button("Fetch AppsFlyer ID") {
                    Haptics.tapLight()
                    appsFlyerID = Analytics.appsFlyerID
                    if appsFlyerID == nil {
                        alert = AlertContent(
                            title: "No AppsFlyer ID",
                            message: "No dev key is set, or the SDK hasn't finished starting."
                        )
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Fire a standard event") {
                    Analytics.track(Analytics.Event.tutorialCompletion, ["source": "growth_screen"])
                    alert = AlertContent(
                        title: "Sent af_tutorial_completion",
                        message: "Standard AppsFlyer event name. Meta and TikTok recognise it with no mapping."
                    )
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - AdMob

    private var adsSection: some View {
        Group {
            SectionLabel("AdMob · ads")
            Card {
                StatusRow(
                    label: "ADS_ENABLED",
                    isOn: AppConfig.adsEnabled,
                    onText: "YES",
                    offText: "NO, ads are off"
                )
                StatusRow(
                    label: "Serving right now",
                    isOn: Ads.canServeAds,
                    onText: "yes",
                    offText: subscriptions.isPro ? "no, user subscribes" : "no"
                )
                Text("Google's test ad unit IDs are wired in, so these work without an AdMob account. Never point them at your real units in development, that's invalid traffic, and it gets accounts banned.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)

                HStack(spacing: 10) {
                    Button("Interstitial") {
                        run {
                            let shown = await Ads.showInterstitial()
                            if !shown {
                                alert = AlertContent(title: "No ad shown", message: "Ads are disabled or unavailable.")
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Rewarded") {
                        run {
                            let earned = await Ads.showRewarded()
                            alert = AlertContent(
                                title: earned ? "Reward earned" : "No reward",
                                message: earned
                                    ? "Grant the reward here, only on the earned callback. Dismissal fires either way."
: "The user closed early, or ads are unavailable."
                            )
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                BannerAdView()
            }
        }
    }

    // MARK: - Ratings

    private var ratingsSection: some View {
        Group {
            SectionLabel("Ratings")
            Card {
                Text("Apple caps the review prompt at three per user per year and gives you no way to know when you're over it: the call just does nothing. Spend the budget after something goes well, never after an error.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)

                HStack(spacing: 10) {
                    Button("Trigger prompt") {
                        Haptics.success()
                        ReviewPrompt.recordPositiveMoment(weight: 5)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Reset counters") { ReviewPrompt.reset() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Helpers

    private func run(_ operation: @escaping () async -> Void) {
        guard !isWorking else { return }
        Task {
            isWorking = true
            await operation()
            isWorking = false
        }
    }
}

#Preview {
    GrowthView().environment(Subscriptions.shared)
}
