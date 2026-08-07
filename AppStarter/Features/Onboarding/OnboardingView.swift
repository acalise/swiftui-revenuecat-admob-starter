import SwiftUI

/// The first-run flow.
///
/// ## Why instrument every step
/// Onboarding is where you lose most users, and the loss is invisible without
/// per-step events: an aggregate "50% finish" tells you nothing about *which*
/// step to fix. Firing `onboarding_step` on every advance turns PostHog's funnel
/// view into a list of exactly where people quit.
///
/// `af_tutorial_completion` at the end is AppsFlyer's standard name for the same
/// milestone, which is what Meta reads as activation. Both come from one
/// `Analytics.track()` call.
///
/// ## Permission prompts belong here, but not on step one
/// Ask for notifications *after* you've said what they're for. A permission
/// dialog on first launch, before any context, is the reliable way to get denied
///, and on iOS a denial is permanent. You cannot ask again; you can only send
/// the user to Settings, which almost nobody does.
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings

    @State private var index = 0
    @State private var isWorking = false

    private struct Step: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let body: String
        let cta: String
    }

    private let steps: [Step] = [
        Step(
            id: "welcome",
            symbol: "sparkles",
            title: "Welcome",
            body: "Replace this with the one sentence that explains why someone should keep the app. Not a feature list: the outcome.",
            cta: "Get started"
        ),
        Step(
            id: "notifications",
            symbol: "bell.badge",
            title: "Stay on track",
            body: "A single daily nudge, at a time you choose. Change it or turn it off in Settings whenever you like.",
            cta: "Enable reminders"
        ),
        Step(
            id: "ready",
            symbol: "checkmark.circle",
            title: "You're all set",
            body: "That's everything. Have a look around, and delete this flow when you replace it with your own.",
            cta: "Start using the app"
        ),
    ]

    private var isLastStep: Bool { index == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Always allow an exit. A user forced through onboarding is a user
            // who deletes the app instead of finishing it.
            HStack {
                Spacer()
                if !isLastStep {
                    Button("Skip", action: skip)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $index) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                    stepPage(step).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 20) {
                PageDots(count: steps.count, current: index)

                Button(isWorking ? "One moment…" : steps[index].cta, action: advance)
                    .buttonStyle(PrimaryButtonStyle(isEnabled: !isWorking))
                    .disabled(isWorking)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Theme.background)
    }

    private func stepPage(_ step: Step) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: step.symbol)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 96, height: 96)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text(step.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.label)
                .padding(.top, 32)

            Text(step.body)
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Actions

    private func advance() {
        Haptics.tap()
        let step = steps[index]
        Analytics.track("onboarding_step", ["step": step.id, "index": index])

        Task {
            if step.id == "notifications" {
                isWorking = true
                // A denial is fine and expected, never block progress on it.
                let granted = await Notifications.requestPermission()
                Analytics.track("notifications_permission", ["granted": granted])
                if granted {
                    settings.remindersEnabled = true
                    await Notifications.scheduleDailyReminder(
                        hour: settings.reminderHour,
                        title: "Daily check-in",
                        body: "Two minutes is all it takes."
                    )
                }
                isWorking = false
            }

            if isLastStep {
                finish()
            } else {
                withAnimation { index += 1 }
            }
        }
    }

    private func skip() {
        Haptics.tapLight()
        Analytics.track("onboarding_skipped", ["at_step": steps[index].id, "index": index])
        finish()
    }

    private func finish() {
        // One call, both providers: PostHog gets the funnel completion, AppsFlyer
        // gets the standard activation event Meta and TikTok optimise toward.
        Analytics.track(Analytics.Event.tutorialCompletion, ["steps": steps.count])
        Haptics.success()
        settings.hasCompletedOnboarding = true
    }
}

/// Page indicator where the active dot stretches into a pill rather than only
/// changing color, which makes position legible even to someone who can't
/// distinguish the two colors.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.accent : Theme.separator)
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings.shared)
}
