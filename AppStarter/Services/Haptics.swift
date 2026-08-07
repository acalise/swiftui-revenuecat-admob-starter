import UIKit

/// Semantic haptic feedback, so call sites say *what happened* rather than which
/// generator to instantiate.
///
/// Two reasons this is worth a file:
///
/// 1. **Generators are cheap to reuse and expensive to churn.** Creating one per
///    tap means the Taptic Engine spins up late and the feedback lands after the
///    animation, which reads as lag. These are created once and kept warm.
///
/// 2. **It makes over-use visible.** When every tap is `Haptics.medium()`, a
///    review that says "this buzzes too much" has one place to fix. Haptics are
///    like sound effects: a few, at meaningful moments, or they become noise the
///    user turns off system-wide, taking your good ones with them.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Subtle, toggles, swipes, micro-interactions.
    static func tapLight() { light.impactOccurred() }

    /// Standard: most button presses.
    static func tap() { medium.impactOccurred() }

    /// Strong, important confirmations, long-press activation.
    static func tapHeavy() { heavy.impactOccurred() }

    /// A picker or segmented control changed.
    static func select() { selection.selectionChanged() }

    /// Task completed, purchase succeeded.
    static func success() { notification.notificationOccurred(.success) }

    /// Non-critical caution.
    static func warning() { notification.notificationOccurred(.warning) }

    /// Destructive action, validation failure.
    static func error() { notification.notificationOccurred(.error) }

    /// Call ~0.1s before you expect to fire a haptic (e.g. on touch-down for a
    /// button whose action fires on touch-up). Wakes the Taptic Engine so the
    /// feedback is instant instead of arriving a frame late.
    static func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
    }
}
