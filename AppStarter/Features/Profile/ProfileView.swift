import SwiftUI

/// A realistic screen, not a component dump.
///
/// The Design tab proves each piece works in isolation; this one shows them
/// composed into the kind of layout you'd actually ship: a header, a stat row,
/// a gated feature, and a list. Copy the structure, replace the data.
///
/// It also demonstrates the pattern you'll use most in a freemium app: read
/// `subscriptions.isPro` to gate a section, with the paywall as the fallback.
struct ProfileView: View {
    @Environment(Subscriptions.self) private var subscriptions
    @State private var showPaywall = false

    private let stats = [("Sessions", "128"), ("Day streak", "14"), ("Saved", "312")]
    private let tags = ["Design", "Swift", "SwiftUI", "Figma"]
    private let activity = [
        ("Completed a session", "2 hours ago"),
        ("Hit a 14-day streak", "Yesterday"),
        ("Updated preferences", "3 days ago"),
    ]

    var body: some View {
        ScreenScrollView(title: "Profile", subtitle: "An example of a composed layout") {
            identityCard
            statsRow
            insightsSection
            activitySection
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var identityCard: some View {
        Card {
            VStack(spacing: 12) {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 76, height: 76)
                    .overlay(
                        Text("AR")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    )

                HStack(spacing: 8) {
                    Text("Alex Rivera")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.label)
                    if subscriptions.isPro {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text("alex@example.com")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)

                // A wrapping row of tags. `Layout` would be more precise, but a
                // simple HStack covers the common case and stays readable.
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.secondaryLabel)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.surfaceSecondary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            ForEach(stats, id: \.0) { label, value in
                VStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.label)
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var insightsSection: some View {
        SectionLabel("Insights")
        if subscriptions.isPro {
            Card {
                Label("Your week at a glance", systemImage: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Text("This block is what a subscriber sees. Gate real features the same way: read `isPro` and branch, never check a product identifier.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)
            }
        } else {
            // The upsell a free user sees. Show the feature's *shape*, not a
            // wall, people convert on something they can already picture using.
            Card {
                Label("Weekly insights", systemImage: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.label)
                Text("See patterns across your sessions, week over week. Available on Pro.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryLabel)
                Button("Unlock insights") {
                    Haptics.tap()
                    showPaywall = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        SectionLabel("Recent activity")
        Card {
            ForEach(Array(activity.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.label)
                            Text(item.1)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.secondaryLabel)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    .padding(.vertical, 6)

                    if index < activity.count - 1 {
                        Divider().background(Theme.separator)
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView().environment(Subscriptions.shared)
}
