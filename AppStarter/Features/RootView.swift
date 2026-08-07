import SwiftUI

/// Decides between onboarding and the main app, then hosts the tab bar.
struct RootView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Group {
            if settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        // Cross-fade rather than a hard swap. The alternative, presenting
        // onboarding as a fullScreenCover over the tab bar, briefly renders the
        // tabs behind it on first launch, which looks like a glitch.
        .animation(.easeInOut(duration: 0.3), value: settings.hasCompletedOnboarding)
    }
}

struct MainTabView: View {
    var body: some View {
        // `.tabItem` rather than iOS 18's `Tab { }` builder, so the deployment
        // target can stay at iOS 17. If you raise it to 18, the `Tab` version is
        // tidier and gives you sidebar adaptation on iPad for free:
        //
        //     Tab("Design", systemImage: "square.grid.2x2") { DesignSystemView() }
        TabView {
            DesignSystemView()
                .tabItem { Label("Design", systemImage: "square.grid.2x2") }
            GrowthView()
                .tabItem { Label("Growth", systemImage: "chart.line.uptrend.xyaxis") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // Tab titles are chrome: they must not grow until they collide. Body
        // copy inside each screen is left uncapped so it scales as far as the
        // user asked.
        .layoutSafeDynamicType()
    }
}

#Preview {
    RootView()
        .environment(AppSettings.shared)
        .environment(Subscriptions.shared)
}
