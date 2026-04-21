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

@MainActor
@Test func windowQueryServiceExcludesTrueFullscreenWindows() async throws {
    let service = WindowQueryService(
        mainDisplayHeightProvider: { 900 },
        testHooks: .init(
            isFullscreenWindow: { _ in true }
        )
    )
    let window = ManagedWindow(
        element: AXUIElementCreateSystemWide(),
        pid: getpid(),
        bundleIdentifier: "com.example.demo",
        appName: "Demo App",
        title: "Demo",
        role: kAXWindowRole as String,
        subrole: kAXStandardWindowSubrole as String,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        identity: "fullscreen-window",
        cgWindowID: nil
    )

    #expect(service.isFullscreenWindowForTesting(window) == true)
    #expect(service.exclusionReasonForTesting(window, configuration: .defaultValue) == "fullscreen-window")
}

@MainActor
@Test func windowQueryServiceExcludesOnlyFullyNonOperableCandidates() async throws {
    let service = WindowQueryService(mainDisplayHeightProvider: { 900 })

    #expect(service.shouldExcludeForOperabilityForTesting(canSetPosition: false, canSetSize: false) == true)
    #expect(service.shouldExcludeForOperabilityForTesting(canSetPosition: true, canSetSize: false) == false)
    #expect(service.shouldExcludeForOperabilityForTesting(canSetPosition: false, canSetSize: true) == false)
    #expect(service.shouldExcludeForOperabilityForTesting(canSetPosition: true, canSetSize: true) == false)
}

@MainActor
@Test func windowQueryServiceRejectsWeakCgToAxMatches() async throws {
    let service = WindowQueryService(mainDisplayHeightProvider: { 900 })
    let settingsWindow = ManagedWindow(
        element: AXUIElementCreateSystemWide(),
        pid: getpid(),
        bundleIdentifier: "com.example.demo",
        appName: "Demo App",
        title: "Settings",
        role: kAXWindowRole as String,
        subrole: kAXStandardWindowSubrole as String,
        frame: CGRect(x: 200, y: 200, width: 800, height: 600),
        identity: "settings-window",
        cgWindowID: nil
    )

    let accepted = service.acceptsMatchForTesting(
        window: settingsWindow,
        expectedTitle: nil,
        expectedBounds: CGRect(x: 0, y: 0, width: 1800, height: 1000),
        point: CGPoint(x: 500, y: 500)
    )

    #expect(accepted == false)
}

@MainActor
@Test func windowQueryServiceRecognizesGridMoveOverlayCgWindow() async throws {
    let service = WindowQueryService(mainDisplayHeightProvider: { 1080 })
    let overlayWindowInfo: [String: Any] = [
        kCGWindowOwnerPID as String: getpid(),
        kCGWindowLayer as String: 25,
        kCGWindowName as String: "",
        kCGWindowBounds as String: [
            "X": 0,
            "Y": 0,
            "Width": 1920,
            "Height": 1080,
        ],
    ]

    #expect(service.isGridMoveOverlayWindowInfoForTesting(overlayWindowInfo) == true)
}
