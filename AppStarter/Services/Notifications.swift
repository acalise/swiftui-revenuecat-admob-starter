import UserNotifications

/// Local notifications.
///
/// Push (remote) notifications need a server, an APNs key, and a device-token
/// round trip. Local notifications need none of that and cover the most common
/// retention mechanic: a daily reminder, so that's what's here.
///
/// ## The rule that matters
/// **Ask for permission after you've explained why.** On iOS a denial is
/// permanent: `requestAuthorization` will never show the prompt again, and your
/// only remaining move is sending the user to Settings, which almost nobody
/// does. A prompt on first launch, before any context, reliably converts worse
/// than the same prompt one screen later, see `OnboardingView`.
@MainActor
enum Notifications {

    /// Ask for permission. Returns whether it was granted.
    ///
    /// Safe to call when already granted (returns true without a prompt) and
    /// when already denied (returns false without a prompt).
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    static var isAuthorized: Bool {
        get async {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional || status == .ephemeral
        }
    }

    /// Schedule a daily reminder at a fixed time, replacing any existing one.
    ///
    /// Note the `cancelAll()`: iOS keeps every request you ever added, so
    /// re-scheduling without cancelling leaves the user with a pile of
    /// duplicates firing at old times. This is the single most common local
    /// notification bug.
    static func scheduleDailyReminder(hour: Int, minute: Int = 0, title: String, body: String) async {
        await cancelAll()

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a one-off notification.
    static func scheduleOnce(after seconds: TimeInterval, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }
}
