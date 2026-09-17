import Foundation
import UserNotifications

protocol ReminderScheduling {
    func scheduleFocusEnd(at date: Date, action: String) async throws
    func cancelFocusEnd()
    func applyDaily(_ settings: ReminderSettings) async throws
}

final class ReminderService: ReminderScheduling {
    static let shared = ReminderService()

    private let focusIdentifier = "better.focus.finished"
    private let startIdentifier = "better.daily.start"
    private let reviewIdentifier = "better.daily.review"

    func requestPermission() async throws -> Bool {
        let center = try notificationCenter()
        return try await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleFocusEnd(at date: Date, action: String) async throws {
        let center = try notificationCenter()
        let allowed = try await ensurePermission(center: center)
        guard allowed else {
            throw ReminderError.permissionDenied
        }

        center.removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "专注时间到了"
        content.body = "现在收尾并记录证据：\(action)"
        content.sound = .default
        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try await center.add(
            UNNotificationRequest(identifier: focusIdentifier, content: content, trigger: trigger)
        )
    }

    func cancelFocusEnd() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [focusIdentifier])
    }

    func applyDaily(_ settings: ReminderSettings) async throws {
        guard settings.enabled else {
            if Bundle.main.bundleIdentifier != nil {
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: [startIdentifier, reviewIdentifier]
                )
            }
            return
        }
        let center = try notificationCenter()
        center.removePendingNotificationRequests(withIdentifiers: [startIdentifier, reviewIdentifier])
        let allowed = try await ensurePermission(center: center)
        guard allowed else {
            throw ReminderError.permissionDenied
        }

        try await addDaily(
            identifier: startIdentifier,
            title: "今天只选一件事",
            body: "先选今天要新增的证据，再开始工作。",
            hour: settings.startHour,
            minute: settings.startMinute,
            center: center
        )
        try await addDaily(
            identifier: reviewIdentifier,
            title: "今天新增了什么证据？",
            body: "记录结果、仍未知的问题，然后停下来。",
            hour: settings.reviewHour,
            minute: settings.reviewMinute,
            center: center
        )
    }

    private func notificationCenter() throws -> UNUserNotificationCenter {
        guard Bundle.main.bundleIdentifier != nil else {
            throw ReminderError.appBundleRequired
        }
        return UNUserNotificationCenter.current()
    }

    private func ensurePermission(center: UNUserNotificationCenter) async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return try await requestPermission()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func addDaily(
        identifier: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        center: UNUserNotificationCenter
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}

enum ReminderError: LocalizedError {
    case permissionDenied
    case appBundleRequired

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "通知权限未开启。请在系统设置的通知中允许 Better。"
        case .appBundleRequired:
            "通知需要从 Better.app 启动；请运行 scripts/build-app.sh 后打开 dist/Better.app。"
        }
    }
}
