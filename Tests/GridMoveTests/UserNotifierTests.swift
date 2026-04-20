import Testing
@testable import GridMove
@preconcurrency import UserNotifications

struct UserNotifierTests {
    @Test func foregroundNotificationsRequestBannerPresentation() {
        let options = UserNotifier.foregroundPresentationOptionsForTesting

        #expect(options.contains(.banner))
        #expect(options.contains(.list))
        #expect(options.contains(.sound))
    }

    @Test func userNotificationCenterSupportRequiresAppBundleAndIdentifier() {
        #expect(
            UserNotifier.supportsUserNotificationCenter(
                bundleURL: URL(fileURLWithPath: "/Applications/GridMove.app"),
                bundleIdentifier: "cn.mirtle.GridMove"
            ) == true
        )
        #expect(
            UserNotifier.supportsUserNotificationCenter(
                bundleURL: URL(fileURLWithPath: "/usr/bin"),
                bundleIdentifier: nil
            ) == false
        )
    }
}
