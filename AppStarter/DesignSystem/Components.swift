import SwiftUI

/// Shared building blocks, so screens describe *what* they show rather than
/// restating padding and corner radii on every view.
///
/// Keep this file small. A design system earns its keep when there are five
/// pieces everyone uses; at fifty, people start writing bespoke views anyway
/// because finding the right component costs more than rewriting it.

// MARK: - Card

/// A rounded container on `Theme.surface`. The default grouping for a set of
/// related rows.
struct Card<Content: View>: View {
    var padding: CGFloat = Theme.padding
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.separator, lineWidth: 1)
        )
    }
}

// MARK: - Buttons

/// The filled primary action. One per screen, two primaries means neither is.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accent.opacity(isEnabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            // A small scale on press reads as responsive in a way a color change
            // doesn't, and it costs nothing.
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary actions, sits on a surface, doesn't compete with the primary.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.label)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Section header

/// Small uppercase label above a group. The iOS Settings idiom.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(Theme.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

// MARK: - Rows

/// A label / value row, as in Settings.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.label)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 16))
    }
}

/// A tappable row with a chevron.
struct NavigationRow: View {
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(isDestructive ? Theme.danger : Theme.label)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .font(.system(size: 16))
            .contentShape(Rectangle()) // the whole row is the hit target, not just the text
        }
        .buttonStyle(.plain)
    }
}

/// A live status line: a dot plus a value. Used on the Growth screen to show,
/// at a glance, which integrations are actually wired into *this* build.
struct StatusRow: View {
    let label: String
    let isOn: Bool
    let onText: String
    let offText: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Theme.label)
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? Theme.success : Theme.secondaryLabel.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(isOn ? onText : offText)
                    .font(.system(size: 15))
                    .foregroundStyle(isOn ? Theme.label : Theme.secondaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

// MARK: - Screen scaffold

/// A scrolling screen with a large title, standard gutters, and the app
/// background. Every tab uses it, which is what keeps them looking related.
struct ScreenScrollView<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Theme.label)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)

                content
            }
            .padding(.horizontal, Theme.padding)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .scrollIndicators(.hidden)
    }
}

// MARK: - Modifiers

extension View {
    /// Caps Dynamic Type at a size the layout can still survive.
    ///
    /// iOS accessibility text scales to roughly 310%. Uncapped, a row-based
    /// layout at that size doesn't degrade gracefully, buttons overflow, labels
    /// collide, tab titles overlap. `.accessibility3` keeps text meaningfully
    /// larger for people who need it while keeping the layout intact.
    ///
    /// Apply it to chrome (tab bars, compact rows), not to body copy, reading
    /// content should scale as far as the user asked. And never use
    /// `.dynamicTypeSize(.large)` as a flat cap: that's the version that ignores
    /// the user's setting outright, which is the accessibility bug people
    /// actually notice.
    func layoutSafeDynamicType() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
