import SwiftUI

/// Appearance, notifications, subscription, and debug tools.
///
/// Also the reference for the two things every shipping app's settings screen
/// needs and most starters omit: a *three-way* appearance control (System is a
/// real choice, not the absence of one), and a restore-purchases row.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.openURL) private var openURL

    @State private var alert: AlertContent?
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        ScreenScrollView(title: "Settings", subtitle: "Preferences and account") {
            appearanceSection(settings: settings)
            notificationsSection(settings: settings)
            subscriptionSection
            aboutSection
            #if DEBUG
            debugSection
            #endif
        }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message)) }
        .confirmationDialog(
            "Reset all local data?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settings.resetAll()
                Haptics.warning()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears every stored preference and restarts onboarding.")
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private func appearanceSection(settings: AppSettings) -> some View {
        SectionLabel("Appearance")
        Card {
            Text("“System” follows the device and keeps following it, that's why it's a third option rather than just the default.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)

            Picker("Appearance", selection: Binding(
                get: { settings.appearance },
                set: { newValue in
                    Haptics.select()
                    settings.appearance = newValue
                    Analytics.track("appearance_changed", ["value": newValue.rawValue])
                }
            )) {
                ForEach(AppSettings.Appearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Divider().background(Theme.separator)

            Text("To rebrand the app, change `Theme.accent` in DesignSystem/Theme.swift. Everything here, and the tab bar, reads that one value.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private func notificationsSection(settings: AppSettings) -> some View {
        SectionLabel("Notifications")
        Card {
            Toggle(isOn: Binding(
                get: { settings.remindersEnabled },
                set: { toggleReminders($0, settings: settings) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.label)
                    Text("A nudge at the same time each day.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .tint(Theme.accent)

            if settings.remindersEnabled {
                Divider().background(Theme.separator)
                Picker("Reminder time", selection: Binding(
                    get: { settings.reminderHour },
                    set: { newHour in
                        Haptics.select()
                        settings.reminderHour = newHour
                        Task { await rescheduleReminder(settings: settings) }
                    }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(hourLabel(hour)).tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }
        }
    }

    private func toggleReminders(_ isOn: Bool, settings: AppSettings) {
        Haptics.tapLight()
        Task {
            if isOn {
                let granted = await Notifications.requestPermission()
                guard granted else {
                    // A denied permission can only be changed in Settings: the
                    // OS will never show the prompt again. Say so.
                    alert = AlertContent(
                        title: "Notifications are off",
                        message: "Turn them on for this app in iOS Settings to get reminders."
                    )
                    return
                }
            }
            settings.remindersEnabled = isOn
            await rescheduleReminder(settings: settings)
            Analytics.track("reminder_toggled", ["enabled": isOn])
        }
    }

    private func rescheduleReminder(settings: AppSettings) async {
        if settings.remindersEnabled {
            await Notifications.scheduleDailyReminder(
                hour: settings.reminderHour,
                title: "Daily check-in",
                body: "Two minutes is all it takes."
            )
        } else {
            await Notifications.cancelAll()
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "AM" : "PM"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display):00 \(suffix)"
    }

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        SectionLabel("Subscription")
        Card {
            InfoRow(label: "Plan", value: subscriptions.isPro ? "Pro" : "Free")
            Divider().background(Theme.separator)

            // Apple requires a restore control wherever a subscription is sold
            // or managed, and it has to work for a reviewer on a clean device.
            NavigationRow(label: "Restore purchases") {
                Haptics.tapLight()
                Task {
                    let result = await subscriptions.restore()
                    if case .failure(let message) = result {
                        alert = AlertContent(title: "Nothing to restore", message: message)
                    } else {
                        alert = AlertContent(title: "Restored", message: "Your subscription is active.")
                    }
                }
            }

            Divider().background(Theme.separator)

            NavigationRow(label: "Manage subscription") {
                // Deep link straight into the App Store's subscription
                // management. Telling people to "open Settings, tap your name,
                // tap Subscriptions" is a support-ticket generator.
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        SectionLabel("About")
        Card {
            InfoRow(label: "Version", value: "\(AppConfig.appVersion) (\(AppConfig.buildNumber))")
            Divider().background(Theme.separator)
            NavigationRow(label: "Rate this app") {
                Haptics.tapLight()
                ReviewPrompt.openStorePage()
            }
            Divider().background(Theme.separator)
            NavigationRow(label: "Privacy policy") { openURL(AppConfig.privacyURL) }
            Divider().background(Theme.separator)
            NavigationRow(label: "Terms of use") { openURL(AppConfig.termsURL) }
        }
    }

    // MARK: - Debug

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        SectionLabel("Developer")
        Card {
            Text("Debug builds only: this whole section is compiled out of release builds.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryLabel)

            HStack(spacing: 8) {
                Button("Force Pro") { subscriptions.setDebugOverride(.pro) }
                Button("Force Free") { subscriptions.setDebugOverride(.free) }
                Button("Clear") { subscriptions.setDebugOverride(nil) }
            }
            .buttonStyle(.bordered)
            .font(.system(size: 14))

            Button("Reset local data") { showResetConfirmation = true }
                .buttonStyle(SecondaryButtonStyle())
                .foregroundStyle(Theme.danger)
        }
    }
    #endif
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
        .environment(Subscriptions.shared)
}
