import SwiftUI

/// User preferences that persist across launches.
///
/// ## Why `@Observable` over scattered `@AppStorage`
/// `@AppStorage` is excellent for a single view's own state. Once a preference
/// is read in three places, it stops being convenient: each view holds its own
/// wrapper, they can disagree mid-update, and there's no single place to put the
/// side effect that should accompany a change (rescheduling a notification when
/// the reminder time moves, for instance).
///
/// One observable object backed by `UserDefaults` keeps the reads consistent and
/// gives every preference an obvious home.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Appearance

    /// Light, dark, or follow the system.
    ///
    /// `.system` is a real, persisted third option, not the absence of a
    /// choice. A user who never touches the setting should keep following their
    /// device as it changes at sunset; a user who explicitly picked Dark should
    /// stay dark at noon. Collapsing this to a boolean is the usual reason an
    /// app's dark mode "randomly turns itself back on".
    enum Appearance: String, CaseIterable, Identifiable {
        case light, dark, system
        var id: String { rawValue }

        var label: String {
            switch self {
            case .light: "Light"
            case .dark: "Dark"
            case .system: "System"
            }
        }

        /// `nil` tells SwiftUI to follow the system.
        var colorScheme: ColorScheme? {
            switch self {
            case .light: .light
            case .dark: .dark
            case .system: nil
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingComplete) }
    }

    // MARK: - Reminders

    var remindersEnabled: Bool {
        didSet { defaults.set(remindersEnabled, forKey: Keys.remindersEnabled) }
    }

    var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) }
    }

    // MARK: - Storage

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearance = "settings.appearance"
        static let onboardingComplete = "settings.onboardingComplete"
        static let remindersEnabled = "settings.remindersEnabled"
        static let reminderHour = "settings.reminderHour"
    }

    private init() {
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete)
        remindersEnabled = defaults.bool(forKey: Keys.remindersEnabled)
        // `integer(forKey:)` returns 0 for a missing key, which would be midnight.
        let storedHour = defaults.object(forKey: Keys.reminderHour) as? Int
        reminderHour = storedHour ?? 9
    }

    /// Debug helper, wipe everything this app stored and start fresh.
    func resetAll() {
        [Keys.appearance, Keys.onboardingComplete, Keys.remindersEnabled, Keys.reminderHour,
         "sub.cachedTier", "sub.debugOverride",
         "review.positiveMoments", "review.lastPromptAt"]
            .forEach(defaults.removeObject(forKey:))

        appearance = .system
        hasCompletedOnboarding = false
        remindersEnabled = false
        reminderHour = 9
    }
}
