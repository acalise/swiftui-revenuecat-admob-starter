import SwiftUI
import UIKit

/// The single source of truth for the app's look.
///
/// Change `Theme.accent` and the whole app follows: buttons, the tab bar, chips,
/// selection states, onboarding, the paywall. Everything reads from here, and
/// nothing hardcodes a color anywhere else.
///
/// ## Why a struct of `Color`s rather than an asset catalog
/// Both work. Asset catalogs are the conventional answer and give you per-appearance
/// values in a visual editor. This starter uses code because:
///
/// - It's greppable and diffable. A color change is a one-line PR, not an opaque
///   `Contents.json` blob.
/// - `Color(light:dark:)` below puts both appearances on one line, next to each
///   other, where a bad contrast pairing is obvious at a glance.
/// - It's copy-paste-able into another project without dragging asset folders.
///
/// If you prefer the catalog, replace the bodies with `Color("Accent")` and keep
/// the same property names, nothing else in the app changes.
enum Theme {

    // MARK: - Brand
    // ── Change these two lines to rebrand the app ────────────────────────────

    /// Primary buttons, selected states, focus, the active tab.
    static let accent = Color(light: 0x3B82F6, dark: 0x3B82F6)

    /// Whatever is drawn ON TOP of `accent`, label text, icons.
    ///
    /// Getting this wrong is the usual cause of an unreadable primary button
    /// after a rebrand. White on a mid-blue; near-black on a yellow or lime.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0xFFFFFF)

    // MARK: - Surfaces

    /// The furthest-back layer.
    static let background = Color(light: 0xFFFFFF, dark: 0x0F0F0F)

    /// Cards and rows sitting on `background`.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)

    /// A second elevation: a chip inside a card, an inset field.
    static let surfaceSecondary = Color(light: 0xF4F4F5, dark: 0x232326)

    // MARK: - Content

    static let label = Color(light: 0x09090B, dark: 0xFAFAFA)
    static let secondaryLabel = Color(light: 0x71717A, dark: 0xA1A1AA)
    static let separator = Color(light: 0xE4E4E7, dark: 0x27272A)

    // MARK: - Status

    static let success = Color(light: 0x10B981, dark: 0x10B981)
    static let warning = Color(light: 0xF59E0B, dark: 0xF59E0B)
    static let danger = Color(light: 0xEF4444, dark: 0xEF4444)

    // MARK: - Shape

    /// Corner radius for cards and buttons. One value drives the whole app's
    /// character, 4 reads sharp and technical, 20 reads soft and consumer.
    static let cornerRadius: CGFloat = 14

    /// Standard gutter. Apple's own apps use 16–20.
    static let padding: CGFloat = 16
}

// MARK: - Appearance-aware colors

extension Color {
    /// A color with distinct light and dark values, written on one line.
    ///
    /// Uses `UIColor`'s dynamic provider, so it resolves at *draw* time against
    /// whatever trait collection the view is in. A `Color` chosen with an `if`
    /// on `@Environment(\.colorScheme)` resolves at *render* time instead, which
    /// means it misses appearance changes that don't re-run the body: the usual
    /// cause of one stubborn view staying light after the system flips to dark.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex : dark): UIColor(hex: light)
        })
    }
}

extension UIColor {
    /// `0xRRGGBB`. Alpha isn't supported on purpose: a design system with
    /// baked-in transparency composites unpredictably over different surfaces.
    /// Use `.opacity()` at the call site, where you can see what's behind it.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
