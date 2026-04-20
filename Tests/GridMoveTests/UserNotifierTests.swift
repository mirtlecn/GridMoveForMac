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
}
