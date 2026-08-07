import SwiftUI

/// The subscription screen.
///
/// ## Why this is hand-built and not RevenueCatUI
/// RevenueCat ships `RevenueCatUI`, which renders paywalls you design in their
/// dashboard and can change without an app release. It's a good product and
/// worth adopting once you're iterating on pricing.
///
/// It isn't the default here because a starter's paywall should be *readable*.
/// This file shows the whole purchase flow in plain SwiftUI: fetch offerings →
/// render plans → buy → handle cancel → dismiss. Once that's clear, swapping in
/// the remote-config version is a five-line change, documented at the bottom of
/// `docs/revenuecat.md`.
///
/// ## The App Review rules baked in here
/// These are the routine rejection causes for a subscription screen. All four
/// are handled below; keep them if you rewrite the layout.
///
/// 1. A visible **Restore Purchases** control (3.1.1). Someone who already paid
///    and reinstalled must get back in without paying twice, and a reviewer on
///    a fresh device *will* look for this.
/// 2. A visible **dismiss** control (3.1.2). Hard paywalls are allowed; a screen
///    with no way out is not.
/// 3. **Price, period and renewal terms** next to the buy button. "$29.99/year,
///    auto-renews, cancel anytime", not just "$29.99".
/// 4. Working **Terms** and **Privacy Policy** links.
///
/// And the one that isn't a rule but costs the most conversions: never lead with
/// price. Show what the money buys, first.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Subscriptions.self) private var subscriptions

    @State private var selectedPlanID: String?
    @State private var isPurchasing = false
    @State private var isLoading = true
    @State private var alert: AlertContent?

    /// What the user is actually buying. Lead with these.
    private let benefits = [
        "Unlimited everything, no daily caps",
        "No ads, anywhere in the app",
        "Sync across all your devices",
        "Priority support from a human",
    ]

    private var selectedPlan: Subscriptions.Plan? {
        subscriptions.plans.first { $0.id == selectedPlanID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            footer
        }
        .background(Theme.background)
        .task { await load() }
        .alert(item: $alert) { content in
            Alert(title: Text(content.title), message: Text(content.message))
        }
    }

    // MARK: - Sections

    /// Rule 2: always a way out.
    private var header: some View {
        HStack {
            Spacer()
            Button {
                Analytics.track("paywall_dismissed")
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(width: 32, height: 32)
                    .background(Theme.surfaceSecondary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("PRO")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.accent)
                    .clipShape(Capsule())

                Text("Everything unlocked")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.label)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                Text("Cancel anytime. Takes two taps.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.top, 6)

                // Value before price.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent)
                                .clipShape(Circle())
                            Text(benefit)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.label)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 28)

                if isLoading {
                    ProgressView().padding(.vertical, 40)
                } else if subscriptions.plans.isEmpty {
                    developmentPlaceholder
                } else {
                    VStack(spacing: 10) {
                        ForEach(subscriptions.plans) { plan in
                            PlanRow(plan: plan, isSelected: plan.id == selectedPlanID) {
                                Haptics.select()
                                selectedPlanID = plan.id
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(buyButtonTitle, action: buy)
                .buttonStyle(PrimaryButtonStyle(isEnabled: !isPurchasing))
                .disabled(isPurchasing)

            // Rule 3: the terms, in plain words, next to the button.
            Text(termsText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                // Rule 1: restore.
                Button("Restore purchases", action: restore)
                // Rule 4: the legal links.
                Link("Terms", destination: AppConfig.termsURL)
                Link("Privacy", destination: AppConfig.privacyURL)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryLabel)
            .disabled(isPurchasing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Theme.background)
        .overlay(alignment: .top) { Divider().background(Theme.separator) }
    }

    /// Shown when RevenueCat has no offerings, no key configured, or the
    /// dashboard isn't set up yet. Keeping the screen usable in this state is
    /// what lets you design the paywall before touching App Store Connect;
    /// `purchase()` grants a local debug unlock so the flow still completes.
    private var developmentPlaceholder: some View {
        Card {
            Text("No offerings loaded")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.label)
            Text("Set REVENUECAT_API_KEY in Secrets.xcconfig and configure an offering in the RevenueCat dashboard to see real plans and prices here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
            Text("Meanwhile, “Continue” grants a local unlock so you can test everything behind the paywall. See docs/revenuecat.md.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    // MARK: - Copy

    private var buyButtonTitle: String {
        if isPurchasing { return "Please wait…" }
        return (selectedPlan?.trialDays ?? 0) > 0 ? "Start free trial" : "Continue"
    }

    private var termsText: String {
        guard let plan = selectedPlan else {
            return "Subscription renews automatically until cancelled. Manage or cancel anytime in your App Store settings."
        }
        let trial = plan.trialDays > 0 ? "\(plan.trialDays) days free, then " : ""
        return "\(trial)\(plan.price) / \(plan.periodLabel.lowercased()). Renews automatically until cancelled. Manage or cancel anytime in your App Store settings."
    }

    // MARK: - Actions

    private func load() async {
        // Fires af_content_view: the event ad networks optimise toward when
        // you're running "reach people likely to view a paywall" campaigns.
        Analytics.track(Analytics.Event.contentView, ["screen": "paywall"])

        await subscriptions.loadPlans()
        // Pre-select the best-value plan. Users overwhelmingly take the default,
        // so this one line moves annual-vs-monthly mix more than most copy changes.
        selectedPlanID = (subscriptions.plans.first(where: \.isAnnual) ?? subscriptions.plans.first)?.id
        isLoading = false
    }

    private func buy() {
        Haptics.tap()
        Analytics.track(Analytics.Event.initiatedCheckout, ["plan": selectedPlan?.periodLabel ?? "debug"])

        Task {
            isPurchasing = true
            let result = await subscriptions.purchase(selectedPlan)
            isPurchasing = false

            switch result {
            case .success:
                Haptics.success()
                dismiss()
            case .cancelled:
                // A user who tapped Cancel does not need an alert telling them
                // they cancelled. Silence is the correct response.
                break
            case .failure(let message):
                Haptics.error()
                alert = AlertContent(title: "Purchase failed", message: message)
            }
        }
    }

    private func restore() {
        Haptics.tapLight()
        Task {
            isPurchasing = true
            let result = await subscriptions.restore()
            isPurchasing = false

            switch result {
            case .success:
                Haptics.success()
                alert = AlertContent(title: "Restored", message: "Your subscription is active again.")
            case .failure(let message):
                alert = AlertContent(title: "Nothing to restore", message: message)
            case .cancelled:
                break
            }
        }
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let plan: Subscriptions.Plan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.accent : Theme.separator, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Theme.accent).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.periodLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.label)
                    if plan.trialDays > 0 {
                        Text("\(plan.trialDays)-day free trial")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    // Always RevenueCat's localised string, never a hardcoded
                    // price, otherwise you show "$29.99" to someone whose store
                    // will charge ¥4,500.
                    Text(plan.price)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.label)
                    if plan.isAnnual {
                        Text("Best value")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }
            }
            .padding(16)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Alert helper

/// `Identifiable` wrapper so `.alert(item:)` can carry a title and message.
struct AlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    PaywallView()
        .environment(Subscriptions.shared)
}
