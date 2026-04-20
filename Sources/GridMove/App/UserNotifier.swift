import Foundation
@preconcurrency import UserNotifications

final class UserNotifier {
    enum Kind: String {
        case configReloadSucceeded = "gridmove-config-reload-succeeded"
        case configReloadSkippedLayouts = "gridmove-config-reload-skipped-layouts"
        case configReloadFailed = "gridmove-config-reload-failed"
        case layoutsSaveFailed = "gridmove-layouts-save-failed"
        case layoutGroupChanged = "gridmove-layout-group-changed"
        case launchAtLoginEnableFailed = "gridmove-launch-at-login-enable-failed"
        case launchAtLoginDisableFailed = "gridmove-launch-at-login-disable-failed"

        var requestIdentifier: String {
            "\(rawValue)-\(UUID().uuidString)"
        }
    }

    private let notifyHandler: (Kind, String, String) -> Void
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    init(notifyHandler: @escaping (Kind, String, String) -> Void = UserNotifier.postSystemNotification) {
        self.notifyHandler = notifyHandler
    }

    func notify(kind: Kind, title: String, body: String) {
        notifyHandler(kind, title, body)
    }

    nonisolated private static func postSystemNotification(kind: Kind, title: String, body: String) {
        guard supportsUserNotificationCenter(
            bundleURL: Bundle.main.bundleURL,
            bundleIdentifier: Bundle.main.bundleIdentifier
        ) else {
            AppLogger.shared.debug("Skipping system notification outside an app bundle.")
            return
        }
        postUserNotificationCenterNotification(kind: kind, title: title, body: body)
    }

    nonisolated private static func postUserNotificationCenterNotification(kind: Kind, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLogger.shared.error("Failed to request notification authorization: \(error.localizedDescription, privacy: .public)")
                return
            }

            guard granted else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: kind.requestIdentifier,
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error {
                    AppLogger.shared.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    static var foregroundPresentationOptionsForTesting: UNNotificationPresentationOptions {
        foregroundPresentationOptions
    }

    static func supportsUserNotificationCenter(bundleURL: URL, bundleIdentifier: String?) -> Bool {
        bundleURL.pathExtension == "app" && bundleIdentifier != nil
    }

    static var supportsUserNotificationCenterForTesting: Bool {
        supportsUserNotificationCenter(
            bundleURL: Bundle.main.bundleURL,
            bundleIdentifier: Bundle.main.bundleIdentifier
        )
    }
}
