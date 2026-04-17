import AppKit
import ApplicationServices
import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func windowQueryServiceDoesNotExcludeBuiltInTitlesWithoutMatchingSystemIdentity() async throws {
    let service = WindowQueryService(mainDisplayHeightProvider: { 900 })
    let window = ManagedWindow(
        element: AXUIElementCreateSystemWide(),
        pid: getpid(),
        bundleIdentifier: "com.example.demo",
        appName: "Demo App",
        title: "Spotlight",
        role: kAXWindowRole as String,
        subrole: kAXStandardWindowSubrole as String,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        identity: "demo-window",
        cgWindowID: nil
    )

    #expect(service.isExcludedByIdentityRulesForTesting(window, configuration: .defaultValue) == false)
}
