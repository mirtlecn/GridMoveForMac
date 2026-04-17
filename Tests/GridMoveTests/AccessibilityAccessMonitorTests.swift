import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func accessibilityAccessMonitorTracksCachedStateAndPollingInterval() async throws {
    var trustState = false
    let monitor = AccessibilityAccessMonitor(statusProvider: { trustState })

    #expect(monitor.hasAccess == false)
    #expect(monitor.pollingInterval == 1.0)

    #expect(monitor.refresh() == true)
    #expect(monitor.hasAccess == false)
    #expect(monitor.pollingInterval == 1.0)

    #expect(monitor.refresh() == false)

    trustState = true
    #expect(monitor.refresh() == true)
    #expect(monitor.hasAccess == true)
    #expect(monitor.pollingInterval == nil)
}

@MainActor
@Test func accessibilityAccessMonitorInvalidationForcesNextRefreshToReportChange() async throws {
    let monitor = AccessibilityAccessMonitor(statusProvider: { true })

    #expect(monitor.refresh() == true)
    #expect(monitor.hasAccess == true)

    monitor.invalidate()

    #expect(monitor.hasAccess == false)
    #expect(monitor.refresh() == true)
    #expect(monitor.hasAccess == true)
}
