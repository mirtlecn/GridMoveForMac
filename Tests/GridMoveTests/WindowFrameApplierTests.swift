import AppKit
import ApplicationServices
import Foundation
import Testing
@testable import GridMove

private func makeManagedWindow(frame: CGRect, identity: String = "window-under-test") -> ManagedWindow {
    ManagedWindow(
        element: AXUIElementCreateSystemWide(),
        pid: getpid(),
        bundleIdentifier: "com.example.demo",
        appName: "Demo App",
        title: "Test Window",
        role: kAXWindowRole as String,
        subrole: kAXStandardWindowSubrole as String,
        frame: frame,
        identity: identity,
        cgWindowID: nil
    )
}

private func decodeSize(from value: AXValue) -> CGSize {
    var size = CGSize.zero
    AXValueGetValue(value, .cgSize, &size)
    return size
}

@MainActor
@Test func windowFrameApplierUsesLiveAccessibilityFrameBeforeCrossScreenHandoff() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    var handoffCount = 0
    var applyFrameCount = 0
    let liveFrame = CGRect(
        x: screen.frame.minX + 40,
        y: screen.frame.minY + 40,
        width: 640,
        height: 480
    )
    let staleFrame = CGRect(x: screen.frame.maxX + 400, y: screen.frame.maxY + 400, width: 640, height: 480)

    let applier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { screen.frame.height },
        screenContainingProvider: { point in
            screen.frame.contains(point) ? screen : nil
        },
        testHooks: .init(
            currentFrameProvider: { _ in liveFrame },
            applyPositionValue: { _, _ in
                handoffCount += 1
                return true
            },
            applyFrameValues: { _, _, _ in
                applyFrameCount += 1
                return true
            }
        )
    )

    applier.applyLayout(
        layoutID: "layout-1",
        to: makeManagedWindow(frame: staleFrame),
        preferredScreen: screen,
        configuration: .defaultValue
    )

    #expect(handoffCount == 0)
    #expect(applyFrameCount == 1)
}

@MainActor
@Test func windowFrameApplierSkipsStaleCrossScreenSettleAfterNewerLayoutRequest() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    let configuration = AppConfiguration.defaultValue
    let fullscreenPreset = try #require(layoutEngine.layoutPreset(for: "layout-10", in: configuration.layouts))
    let thirdsPreset = try #require(layoutEngine.layoutPreset(for: "layout-1", in: configuration.layouts))
    let fullscreenFrame = try #require(
        layoutEngine.frame(
            for: fullscreenPreset,
            on: screen,
            layoutGap: configuration.appearance.effectiveLayoutGap
        )
    )
    let thirdsFrame = try #require(
        layoutEngine.frame(
            for: thirdsPreset,
            on: screen,
            layoutGap: configuration.appearance.effectiveLayoutGap
        )
    )
    var scheduledWorkItems: [DispatchWorkItem] = []
    var appliedSizes: [CGSize] = []

    let applier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { screen.frame.height },
        screenContainingProvider: { _ in nil },
        testHooks: .init(
            currentFrameProvider: { _ in CGRect(x: 0, y: 0, width: 960, height: 720) },
            applyPositionValue: { _, _ in true },
            applyFrameValues: { _, sizeValue, _ in
                appliedSizes.append(decodeSize(from: sizeValue))
                return true
            },
            scheduleCrossScreenSettle: { workItem in
                scheduledWorkItems.append(workItem)
            }
        )
    )

    let window = makeManagedWindow(frame: CGRect(x: -2000, y: -2000, width: 960, height: 720))

    applier.applyLayout(
        layoutID: "layout-10",
        to: window,
        preferredScreen: screen,
        configuration: configuration
    )
    applier.applyLayout(
        layoutID: "layout-1",
        to: window,
        preferredScreen: screen,
        configuration: configuration
    )

    #expect(scheduledWorkItems.count == 2)

    scheduledWorkItems[0].perform()
    scheduledWorkItems[1].perform()

    #expect(appliedSizes.count == 3)
    #expect(abs(appliedSizes[0].width - fullscreenFrame.width) < 0.5)
    #expect(abs(appliedSizes[0].height - fullscreenFrame.height) < 0.5)
    #expect(abs(appliedSizes[1].width - thirdsFrame.width) < 0.5)
    #expect(abs(appliedSizes[1].height - thirdsFrame.height) < 0.5)
    #expect(abs(appliedSizes[2].width - thirdsFrame.width) < 0.5)
    #expect(abs(appliedSizes[2].height - thirdsFrame.height) < 0.5)
}

@MainActor
@Test func windowFrameApplierSkipsCollapsedLayoutFrames() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    var applyFrameCount = 0
    var configuration = AppConfiguration.defaultValue
    configuration.appearance.layoutGap = 10_000

    let applier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { screen.frame.height },
        screenContainingProvider: { point in
            screen.frame.contains(point) ? screen : nil
        },
        testHooks: .init(
            currentFrameProvider: { _ in CGRect(x: 0, y: 0, width: 960, height: 720) },
            applyPositionValue: { _, _ in false },
            applyFrameValues: { _, _, _ in
                applyFrameCount += 1
                return true
            }
        )
    )

    applier.applyLayout(
        layoutID: "layout-1",
        to: makeManagedWindow(frame: CGRect(x: 0, y: 0, width: 960, height: 720)),
        preferredScreen: screen,
        configuration: configuration
    )

    #expect(applyFrameCount == 0)
}

@MainActor
@Test func windowFrameApplierSkipsTrueFullscreenWindowLayoutApply() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    var applyFrameCount = 0
    var handoffCount = 0

    let applier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { screen.frame.height },
        screenContainingProvider: { point in
            screen.frame.contains(point) ? screen : nil
        },
        testHooks: .init(
            currentFrameProvider: { _ in CGRect(x: 0, y: 0, width: 960, height: 720) },
            applyPositionValue: { _, _ in
                handoffCount += 1
                return true
            },
            applyFrameValues: { _, _, _ in
                applyFrameCount += 1
                return true
            },
            isFullscreenWindow: { _ in true }
        )
    )

    applier.applyLayout(
        layoutID: "layout-1",
        to: makeManagedWindow(frame: CGRect(x: 0, y: 0, width: 960, height: 720)),
        preferredScreen: screen,
        configuration: .defaultValue
    )

    #expect(handoffCount == 0)
    #expect(applyFrameCount == 0)
}

@MainActor
@Test func windowFrameApplierSkipsTrueFullscreenWindowMove() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    var applyPositionCount = 0

    let applier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { screen.frame.height },
        screenContainingProvider: { point in
            screen.frame.contains(point) ? screen : nil
        },
        testHooks: .init(
            applyPositionValue: { _, _ in
                applyPositionCount += 1
                return true
            },
            isFullscreenWindow: { _ in true }
        )
    )

    let didMove = applier.moveWindow(
        to: CGPoint(x: 80, y: 120),
        currentFrame: CGRect(x: 40, y: 50, width: 960, height: 720),
        for: makeManagedWindow(frame: CGRect(x: 40, y: 50, width: 960, height: 720))
    )

    #expect(didMove == false)
    #expect(applyPositionCount == 0)
}
