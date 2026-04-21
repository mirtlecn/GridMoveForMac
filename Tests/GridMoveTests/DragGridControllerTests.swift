import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import GridMove

private func makeScrollEvent(deltaY: Int32) throws -> CGEvent {
    let source = try #require(CGEventSource(stateID: .hidSystemState))
    return try #require(
        CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: deltaY,
            wheel2: 0,
            wheel3: 0
        )
    )
}

private func makeOtherMouseEvent(type: CGEventType, buttonNumber: Int64, point: CGPoint = .zero) throws -> CGEvent {
    let source = try #require(CGEventSource(stateID: .hidSystemState))
    let mouseButton = try #require(CGMouseButton(rawValue: UInt32(buttonNumber)))
    let event = try #require(
        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: mouseButton
        )
    )
    event.setIntegerValueField(CGEventField.mouseEventButtonNumber, value: buttonNumber)
    return event
}

private func makeLeftMouseEvent(type: CGEventType, point: CGPoint) throws -> CGEvent {
    let source = try #require(CGEventSource(stateID: .hidSystemState))
    return try #require(
        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        )
    )
}

private func makeKeyEvent(key: String) throws -> CGEvent {
    let source = try #require(CGEventSource(stateID: .hidSystemState))
    let keyCode = try #require(ShortcutKeyMap.keyCode(for: key))
    return try #require(
        CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        )
    )
}

private func makeManagedWindow(frame: CGRect, identity: String = "drag-grid-window") -> ManagedWindow {
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

@MainActor
private final class OverlayUpdateRecorder {
    var screen: NSScreen?
    var slots: [ResolvedTriggerSlot] = []
    var highlightFrame: CGRect?
    var hoveredLayoutID: String?

    func record(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?
    ) {
        self.screen = screen
        self.slots = slots
        self.highlightFrame = highlightFrame
        self.hoveredLayoutID = hoveredLayoutID
    }
}

@MainActor
@Test func preferredInteractionModeDefaultsToLayoutSelection() async throws {
    #expect(DragGridController.preferredInteractionMode(preferLayoutMode: true) == .layoutSelection)
    #expect(DragGridController.preferredInteractionMode(preferLayoutMode: false) == .moveOnly)
}

@Test func modeToggleReturnsToLayoutSelectionWithoutImmediateLayoutApply() async throws {
    let interactionMode = DragInteractionMode.moveOnly
    let nextMode: DragInteractionMode = interactionMode == .moveOnly ? .layoutSelection : .moveOnly

    #expect(nextMode == .layoutSelection)
    #expect(nextMode != .moveOnly)
}

@Test func optionToggleTrackerTogglesAfterPressThenRelease() async throws {
    var tracker = OptionToggleTracker(baselineModifiers: [])

    #expect(tracker.register(modifiers: [.alt]) == .consume)
    #expect(tracker.isPending == true)
    #expect(tracker.register(modifiers: []) == .toggle)
    #expect(tracker.isPending == false)
}

@Test func optionToggleTrackerTogglesAfterReleaseThenPress() async throws {
    var tracker = OptionToggleTracker(baselineModifiers: [.alt])

    #expect(tracker.register(modifiers: []) == .ignore)
    #expect(tracker.register(modifiers: [.alt]) == .consume)
    #expect(tracker.isPending == true)
    #expect(tracker.register(modifiers: []) == .toggle)
    #expect(tracker.isPending == false)
}

@Test func optionToggleTrackerIgnoresRepeatedState() async throws {
    var tracker = OptionToggleTracker(baselineModifiers: [])

    #expect(tracker.register(modifiers: []) == .ignore)
    #expect(tracker.register(modifiers: [.alt]) == .consume)
    #expect(tracker.register(modifiers: [.alt]) == .ignore)
}

@Test func optionToggleTrackerIgnoresOptionCombinedWithOtherModifiers() async throws {
    var tracker = OptionToggleTracker(baselineModifiers: [])

    #expect(tracker.register(modifiers: [.alt, .cmd]) == .ignore)
    #expect(tracker.isPending == false)
}

@Test func optionToggleTrackerCancelsPendingToggleWhenAnotherModifierAppears() async throws {
    var tracker = OptionToggleTracker(baselineModifiers: [])

    #expect(tracker.register(modifiers: [.alt]) == .consume)
    #expect(tracker.register(modifiers: [.alt, .shift]) == .consume)
    #expect(tracker.isPending == false)
    #expect(tracker.register(modifiers: []) == .ignore)
}

@Test func shiftGroupCycleTrackerTogglesAfterPressThenRelease() async throws {
    var tracker = ShiftGroupCycleTracker(baselineModifiers: [])

    #expect(tracker.register(modifiers: [.shift]) == .consume)
    #expect(tracker.register(modifiers: []) == .toggle)
}

@Test func nextLayoutGroupNameInCycleSkipsExcludedGroupsAndWraps() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    configuration.layoutGroups = [
        LayoutGroup(name: "work", includeInGroupCycle: true, sets: []),
        LayoutGroup(name: "game", includeInGroupCycle: false, sets: []),
        LayoutGroup(name: "fullscreen", includeInGroupCycle: true, sets: []),
    ]

    #expect(configuration.nextLayoutGroupNameInCycle() == "work")

    configuration.general.activeLayoutGroup = "game"
    #expect(configuration.nextLayoutGroupNameInCycle() == "fullscreen")

    configuration.layoutGroups = [
        LayoutGroup(name: "work", includeInGroupCycle: false, sets: []),
        LayoutGroup(name: "game", includeInGroupCycle: true, sets: []),
    ]
    configuration.general.activeLayoutGroup = "game"
    #expect(configuration.nextLayoutGroupNameInCycle() == nil)
    #expect(configuration.previousLayoutGroupNameInCycle() == nil)

    configuration.layoutGroups = [
        LayoutGroup(name: "work", includeInGroupCycle: true, sets: []),
        LayoutGroup(name: "game", includeInGroupCycle: false, sets: []),
        LayoutGroup(name: "fullscreen", includeInGroupCycle: true, sets: []),
    ]
    configuration.general.activeLayoutGroup = "work"
    #expect(configuration.previousLayoutGroupNameInCycle() == "fullscreen")
}

@Test func moveAnchorPreservesPointerOffset() async throws {
    let anchor = MoveAnchor(
        mousePoint: CGPoint(x: 400, y: 300),
        windowOrigin: CGPoint(x: 120, y: 80)
    )

    #expect(anchor.movedOrigin(for: CGPoint(x: 460, y: 355)) == CGPoint(x: 180, y: 135))
}

@MainActor
@Test func moveOnlyDragCoalescesUpdatesUntilMinimumInterval() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var currentTime: TimeInterval = 10
    var appliedOrigins: [CGPoint] = []
    var overlayRefreshCount = 0

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentTimeProvider: { currentTime },
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            },
            refreshOverlay: { _ in
                overlayRefreshCount += 1
            }
        )
    )

    controller.state.active = true
    controller.state.interactionMode = .moveOnly
    controller.state.targetWindow = makeManagedWindow(frame: CGRect(x: 120, y: 80, width: 300, height: 200))
    controller.state.currentWindowFrame = CGRect(x: 120, y: 80, width: 300, height: 200)
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: CGPoint(x: 400, y: 300),
        windowOrigin: CGPoint(x: 120, y: 80)
    )

    controller.updateMoveOnlyDrag(at: CGPoint(x: 440, y: 340))
    #expect(appliedOrigins == [CGPoint(x: 160, y: 120)])
    #expect(controller.state.currentWindowFrame?.origin == CGPoint(x: 160, y: 120))
    #expect(overlayRefreshCount == 1)

    currentTime += 0.002
    controller.updateMoveOnlyDrag(at: CGPoint(x: 470, y: 360))

    #expect(appliedOrigins == [CGPoint(x: 160, y: 120)])
    #expect(controller.state.pendingDragMovePoint == CGPoint(x: 470, y: 360))
    #expect(controller.state.currentWindowFrame?.origin == CGPoint(x: 160, y: 120))
    #expect(overlayRefreshCount == 1)

    currentTime += 0.010
    controller.updateMoveOnlyDrag(at: CGPoint(x: 500, y: 390))

    #expect(appliedOrigins == [CGPoint(x: 160, y: 120), CGPoint(x: 220, y: 170)])
    #expect(controller.state.pendingDragMovePoint == nil)
    #expect(controller.state.currentWindowFrame?.origin == CGPoint(x: 220, y: 170))
    #expect(overlayRefreshCount == 2)
}

@MainActor
@Test func triggerKeyXClosesWindowAndExitsInteraction() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    let targetWindow = makeManagedWindow(frame: CGRect(x: 120, y: 80, width: 300, height: 200))
    var closedWindowIDs: [String] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            closeWindow: { window in
                closedWindowIDs.append(window.identity)
                return true
            }
        )
    )

    controller.state.active = true
    controller.state.activeButton = .mouseButton
    controller.state.interactionMode = .layoutSelection
    controller.state.targetWindow = targetWindow

    let result = try controller.handleKeyDown(event: makeKeyEvent(key: "x"), configuration: .defaultValue)

    #expect(result == nil)
    #expect(closedWindowIDs == [targetWindow.identity])
    #expect(controller.state.active == false)
    #expect(controller.state.targetWindow == nil)
    #expect(controller.state.suppressedMouseUpButton == .mouseButton)
}

@MainActor
@Test func triggerDigitZeroAppliesLayoutIndexTenAndExitsFromMoveMode() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    let configuration = AppConfiguration.defaultValue
    let screen = try #require(NSScreen.screens.first)
    let targetWindow = makeManagedWindow(frame: CGRect(x: 120, y: 80, width: 300, height: 200))
    let expectedEntry = try #require(LayoutGroupResolver.entry(at: 10, configuration: configuration))
    var appliedLayoutID: String?
    var appliedScreenIdentifier: String?

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            applyLayout: { layoutID, _, preferredScreen, _ in
                appliedLayoutID = layoutID
                appliedScreenIdentifier = preferredScreen.map(Geometry.screenIdentifier(for:))
            }
        )
    )

    controller.state.active = true
    controller.state.activeButton = .left
    controller.state.interactionMode = .moveOnly
    controller.state.targetWindow = targetWindow
    controller.state.activeScreen = screen

    let result = try controller.handleKeyDown(event: makeKeyEvent(key: "0"), configuration: configuration)

    #expect(result == nil)
    #expect(appliedLayoutID == expectedEntry.layout.id)
    #expect(appliedScreenIdentifier == Geometry.screenIdentifier(for: screen))
    #expect(controller.state.active == false)
    #expect(controller.state.targetWindow == nil)
    #expect(controller.state.suppressedMouseUpButton == .left)
}

@MainActor
@Test func moveOnlyDragMouseUpFlushesLatestPendingPoint() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var currentTime: TimeInterval = 20
    var appliedOrigins: [CGPoint] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentTimeProvider: { currentTime },
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            }
        )
    )

    controller.state.active = true
    controller.state.activeButton = .left
    controller.state.interactionMode = .moveOnly
    controller.state.targetWindow = makeManagedWindow(frame: CGRect(x: 120, y: 80, width: 300, height: 200))
    controller.state.currentWindowFrame = CGRect(x: 120, y: 80, width: 300, height: 200)
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: CGPoint(x: 400, y: 300),
        windowOrigin: CGPoint(x: 120, y: 80)
    )

    controller.updateMoveOnlyDrag(at: CGPoint(x: 440, y: 340))
    currentTime += 0.001
    controller.updateMoveOnlyDrag(at: CGPoint(x: 500, y: 390))

    #expect(appliedOrigins == [CGPoint(x: 160, y: 120)])
    #expect(controller.state.pendingDragMovePoint == CGPoint(x: 500, y: 390))

    _ = controller.handleMouseUp(
        event: try makeLeftMouseEvent(type: .leftMouseUp, point: .zero),
        button: .left,
        configuration: .defaultValue
    )

    #expect(appliedOrigins == [CGPoint(x: 160, y: 120), CGPoint(x: 220, y: 170)])
    #expect(controller.state.active == false)
}

@MainActor
@Test func moveOnlyDragRefreshesOverlayFromLiveWindowFrame() async throws {
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    let initialFrame = CGRect(x: 120, y: 80, width: 300, height: 200)
    let liveFrame = CGRect(x: 172, y: 126, width: 300, height: 200)
    let targetWindow = makeManagedWindow(frame: initialFrame)
    let currentTime: TimeInterval = 10
    var appliedOrigins: [CGPoint] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentTimeProvider: { currentTime },
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            },
            currentWindowFrame: { _ in liveFrame }
        )
    )

    controller.state.active = true
    controller.state.interactionMode = .moveOnly
    controller.state.targetWindow = targetWindow
    controller.state.cursorPoint = CGPoint(x: initialFrame.midX, y: initialFrame.midY)
    controller.state.currentWindowFrame = initialFrame
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: CGPoint(x: 400, y: 300),
        windowOrigin: initialFrame.origin
    )

    controller.updateMoveOnlyDrag(at: CGPoint(x: 440, y: 340))

    #expect(appliedOrigins == [CGPoint(x: 160, y: 120)])
    #expect(controller.state.currentWindowFrame == liveFrame)
    #expect(recorder.highlightFrame == liveFrame)
}

@MainActor
@Test func layoutGroupCycleReturnsToThresholdPhaseBeforeApplyingLayouts() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var updatedConfiguration = AppConfiguration.defaultValue
    updatedConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { AppConfiguration.defaultValue },
        cycleActiveLayoutGroup: { _ in updatedConfiguration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.currentWindowFrame = CGRect(
        x: screen.frame.minX + 40,
        y: screen.frame.minY + 40,
        width: 320,
        height: 240
    )
    controller.state.hasDraggedPastThreshold = true
    controller.state.hoveredLayoutID = "layout-1"
    controller.state.lastAppliedLayoutID = "layout-1"

    controller.cycleLayoutGroup(at: CGPoint(x: screen.frame.minX + 60, y: screen.frame.minY + 60))

    #expect(controller.state.hasDraggedPastThreshold == false)
    #expect(controller.state.hoveredLayoutID == nil)
    #expect(controller.state.lastAppliedLayoutID == nil)
    #expect(controller.state.activeScreen != nil)
}

@MainActor
@Test func overlayHighlightFallsBackToCurrentWindowFrameBeforeDragThreshold() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(x: 10, y: 20, width: 300, height: 200)
    controller.state.interactionMode = .layoutSelection
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.hasDraggedPastThreshold = false
    controller.state.hoveredLayoutID = nil

    #expect(controller.overlayHighlightFrame(configuration: .defaultValue) == currentWindowFrame)
}

@MainActor
@Test func deferredLayoutModeHidesWindowHighlightWhenNoLayoutIsHovered() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 80, y: screen.frame.minY + 60, width: 320, height: 240)
    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.hasDraggedPastThreshold = true
    controller.state.hoveredLayoutID = nil

    controller.refreshOverlay(configuration: .defaultValue)

    #expect(recorder.highlightFrame == nil)
    #expect(recorder.hoveredLayoutID == nil)
}

@MainActor
@Test func immediateLayoutModeKeepsActualWindowHighlightWhenNoLayoutIsHovered() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = true

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 80, y: screen.frame.minY + 60, width: 320, height: 240)
    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.hasDraggedPastThreshold = true
    controller.state.hoveredLayoutID = nil

    controller.refreshOverlay(configuration: configuration)

    #expect(recorder.highlightFrame == currentWindowFrame)
    #expect(recorder.hoveredLayoutID == nil)
}

@MainActor
@Test func moveModeUsesCurrentWindowFrameForWindowHighlight() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 100, y: screen.frame.minY + 90, width: 360, height: 260)
    controller.state.active = true
    controller.state.interactionMode = .moveOnly
    controller.state.cursorPoint = CGPoint(x: currentWindowFrame.midX, y: currentWindowFrame.midY)
    controller.state.currentWindowFrame = currentWindowFrame

    controller.refreshOverlay(configuration: .defaultValue)

    #expect(recorder.highlightFrame == currentWindowFrame)
    #expect(recorder.slots.isEmpty)
    #expect(recorder.hoveredLayoutID == nil)
}

@MainActor
@Test func switchingFromLayoutPreviewToMoveModeRestoresActualWindowHighlight() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = false

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 120, y: screen.frame.minY + 120, width: 320, height: 240)
    let targetWindow = makeManagedWindow(frame: currentWindowFrame)
    let resolvedSlots = layoutEngine.resolveTriggerSlots(
        on: screen,
        layouts: LayoutGroupResolver.triggerableLayouts(for: screen, configuration: configuration),
        triggerGap: Double(configuration.appearance.triggerGap),
        layoutGap: configuration.appearance.effectiveLayoutGap
    )
    let hoveredSlot = try #require(resolvedSlots.first)
    let togglePoint = CGPoint(x: currentWindowFrame.midX, y: currentWindowFrame.midY)

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.activeScreen = screen
    controller.state.cursorPoint = togglePoint
    controller.state.resolvedSlots = resolvedSlots
    controller.state.hasDraggedPastThreshold = true
    controller.state.hoveredLayoutID = hoveredSlot.layoutID

    #expect(controller.overlayHighlightFrame(configuration: configuration) == hoveredSlot.targetFrame)

    controller.configureMoveOnlyMode(at: togglePoint, configuration: configuration)

    #expect(recorder.highlightFrame == currentWindowFrame)
    #expect(recorder.hoveredLayoutID == nil)
}

@MainActor
@Test func switchingToMoveModeRefreshesOverlayFromLiveWindowFrame() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    let staleFrame = CGRect(x: screen.frame.minX + 80, y: screen.frame.minY + 80, width: 500, height: 300)
    let liveFrame = CGRect(x: screen.frame.minX + 130, y: screen.frame.minY + 140, width: 360, height: 220)
    let targetWindow = makeManagedWindow(frame: staleFrame)

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentWindowFrame: { _ in liveFrame }
        )
    )

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = staleFrame

    controller.configureMoveOnlyMode(
        at: CGPoint(x: liveFrame.midX, y: liveFrame.midY),
        configuration: .defaultValue
    )

    #expect(controller.state.currentWindowFrame == liveFrame)
    #expect(recorder.highlightFrame == liveFrame)
}

@MainActor
@Test func deferredLayoutSelectionDragMovesWindowAfterThresholdUsingSharedThrottle() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = false
    var currentTime: TimeInterval = 30
    var appliedOrigins: [CGPoint] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentTimeProvider: { currentTime },
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            }
        )
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 120, y: screen.frame.minY + 80, width: 320, height: 240)
    let targetWindow = makeManagedWindow(frame: currentWindowFrame)
    let activationPoint = CGPoint(x: currentWindowFrame.midX, y: currentWindowFrame.midY)
    let nonTriggerPoint = CGPoint(x: screen.frame.midX, y: screen.frame.midY)

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.overlayActivationPoint = activationPoint
    controller.state.resolvedSlots = []
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: activationPoint,
        windowOrigin: currentWindowFrame.origin
    )

    controller.updateLayoutSelectionDrag(at: nonTriggerPoint, configuration: configuration)
    #expect(controller.state.hasDraggedPastThreshold == true)
    #expect(appliedOrigins.count == 1)
    #expect(controller.state.hoveredLayoutID == nil)
    #expect(recorder.highlightFrame == nil)

    currentTime += 0.002
    let throttledPoint = CGPoint(x: nonTriggerPoint.x + 40, y: nonTriggerPoint.y - 20)
    controller.updateLayoutSelectionDrag(at: throttledPoint, configuration: configuration)

    #expect(appliedOrigins.count == 1)
    #expect(controller.state.pendingDragMovePoint == throttledPoint)
}

@MainActor
@Test func deferredLayoutSelectionHoverKeepsMovingWithoutImmediateApply() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = false
    var currentTime: TimeInterval = 40
    var appliedOrigins: [CGPoint] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentTimeProvider: { currentTime },
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            }
        )
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 80, y: screen.frame.minY + 80, width: 320, height: 240)
    let targetWindow = makeManagedWindow(frame: currentWindowFrame)
    let resolvedSlots = layoutEngine.resolveTriggerSlots(
        on: screen,
        layouts: LayoutGroupResolver.triggerableLayouts(for: screen, configuration: configuration),
        triggerGap: Double(configuration.appearance.triggerGap),
        layoutGap: configuration.appearance.effectiveLayoutGap
    )
    let hoveredSlot = try #require(resolvedSlots.first)
    let activationPoint = CGPoint(x: currentWindowFrame.midX, y: currentWindowFrame.midY)
    let hoverPoint = CGPoint(x: hoveredSlot.triggerFrame.midX, y: hoveredSlot.triggerFrame.midY)

    controller.state.active = true
    controller.state.activeButton = .left
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.overlayActivationPoint = activationPoint
    controller.state.resolvedSlots = resolvedSlots
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: activationPoint,
        windowOrigin: currentWindowFrame.origin
    )

    controller.updateLayoutSelectionDrag(at: hoverPoint, configuration: configuration)

    #expect(appliedOrigins.count == 1)
    #expect(controller.state.hoveredLayoutID == hoveredSlot.layoutID)
    #expect(controller.state.lastAppliedLayoutID == nil)
    #expect(recorder.highlightFrame == hoveredSlot.targetFrame)

    currentTime += 0.001
    let mouseUpPoint = CGPoint(x: hoverPoint.x + 30, y: hoverPoint.y + 20)
    controller.updateLayoutSelectionDrag(at: mouseUpPoint, configuration: configuration)
    #expect(controller.state.pendingDragMovePoint == mouseUpPoint)

    _ = controller.handleMouseUp(
        event: try makeLeftMouseEvent(
            type: .leftMouseUp,
            point: controller.windowController.quartzPoint(fromAppKitPoint: mouseUpPoint)
        ),
        button: .left,
        configuration: configuration
    )

    #expect(appliedOrigins.count == 2)
    #expect(controller.state.active == false)
}

@MainActor
@Test func immediateLayoutSelectionDoesNotMoveWindowWhileDragging() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = true
    var appliedOrigins: [CGPoint] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            moveWindow: { origin, _, _ in
                appliedOrigins.append(origin)
                return true
            }
        )
    )

    let currentWindowFrame = CGRect(x: screen.frame.minX + 80, y: screen.frame.minY + 80, width: 320, height: 240)
    let targetWindow = makeManagedWindow(frame: currentWindowFrame)
    let resolvedSlots = layoutEngine.resolveTriggerSlots(
        on: screen,
        layouts: LayoutGroupResolver.triggerableLayouts(for: screen, configuration: configuration),
        triggerGap: Double(configuration.appearance.triggerGap),
        layoutGap: configuration.appearance.effectiveLayoutGap
    )
    let hoveredSlot = try #require(resolvedSlots.first)
    let activationPoint = CGPoint(x: currentWindowFrame.midX, y: currentWindowFrame.midY)
    let hoverPoint = CGPoint(x: hoveredSlot.triggerFrame.midX, y: hoveredSlot.triggerFrame.midY)

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.overlayActivationPoint = activationPoint
    controller.state.resolvedSlots = resolvedSlots
    controller.state.moveAnchor = MoveAnchor(
        mousePoint: activationPoint,
        windowOrigin: currentWindowFrame.origin
    )

    controller.updateLayoutSelectionDrag(at: hoverPoint, configuration: configuration)

    #expect(appliedOrigins.isEmpty)
}

@MainActor
@Test func switchingToLayoutModeRefreshesOverlayFromLiveWindowFrame() async throws {
    let screen = try #require(NSScreen.screens.first)
    let recorder = OverlayUpdateRecorder()
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController(
        testHooks: .init(
            showOverlay: { screen, slots, highlightFrame, hoveredLayoutID, _, _ in
                recorder.record(
                    screen: screen,
                    slots: slots,
                    highlightFrame: highlightFrame,
                    hoveredLayoutID: hoveredLayoutID
                )
            }
        )
    )
    let staleFrame = CGRect(x: screen.frame.minX + 90, y: screen.frame.minY + 90, width: 520, height: 320)
    let liveFrame = CGRect(x: screen.frame.minX + 150, y: screen.frame.minY + 150, width: 340, height: 210)
    let targetWindow = makeManagedWindow(frame: staleFrame)

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { .defaultValue },
        cycleActiveLayoutGroup: { _ in .defaultValue },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {},
        testHooks: .init(
            currentWindowFrame: { _ in liveFrame }
        )
    )

    controller.state.active = true
    controller.state.interactionMode = .moveOnly
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = staleFrame

    controller.configureLayoutSelectionMode(
        at: CGPoint(x: liveFrame.midX, y: liveFrame.midY),
        configuration: .defaultValue,
        shouldApplyImmediately: false
    )

    #expect(controller.state.currentWindowFrame == liveFrame)
    #expect(recorder.highlightFrame == liveFrame)
}

@MainActor
@Test func deferredLayoutApplyWaitsForMouseUp() async throws {
    let screen = try #require(NSScreen.screens.first)
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = false

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let currentWindowFrame = CGRect(
        x: screen.frame.minX + 40,
        y: screen.frame.minY + 40,
        width: 320,
        height: 240
    )
    let targetWindow = makeManagedWindow(frame: currentWindowFrame)
    let resolvedSlots = layoutEngine.resolveTriggerSlots(
        on: screen,
        layouts: LayoutGroupResolver.triggerableLayouts(for: screen, configuration: configuration),
        triggerGap: Double(configuration.appearance.triggerGap),
        layoutGap: configuration.appearance.effectiveLayoutGap
    )
    let hoveredSlot = try #require(resolvedSlots.first)
    let hoverPoint = CGPoint(x: hoveredSlot.triggerFrame.midX, y: hoveredSlot.triggerFrame.midY)

    controller.state.active = true
    controller.state.activeButton = .left
    controller.state.interactionMode = .layoutSelection
    controller.state.activeScreen = screen
    controller.state.targetWindow = targetWindow
    controller.state.currentWindowFrame = currentWindowFrame
    controller.state.resolvedSlots = resolvedSlots
    controller.state.hasDraggedPastThreshold = true

    controller.updateLayoutSelection(at: hoverPoint, configuration: configuration)

    #expect(controller.state.hoveredLayoutID == hoveredSlot.layoutID)
    #expect(controller.state.lastAppliedLayoutID == nil)
    #expect(controller.state.currentWindowFrame == currentWindowFrame)
    #expect(controller.overlayHighlightFrame(configuration: configuration) == hoveredSlot.targetFrame)

    controller.finalizeLayoutSelection(at: hoverPoint, configuration: configuration)

    #expect(controller.state.lastAppliedLayoutID == hoveredSlot.layoutID)
    #expect(controller.state.currentWindowFrame == hoveredSlot.targetFrame)

    _ = controller.handleMouseUp(
        event: try makeLeftMouseEvent(type: .leftMouseUp, point: controller.windowController.quartzPoint(fromAppKitPoint: hoverPoint)),
        button: .left,
        configuration: configuration
    )

    #expect(controller.state.active == false)
}

@MainActor
@Test func scrollGroupCycleTrackerTriggersOncePerGestureAfterThreshold() async throws {
    var tracker = ScrollGroupCycleTracker(threshold: 6)

    #expect(tracker.register(distance: 2) == nil)
    #expect(tracker.register(distance: 3) == nil)
    #expect(tracker.register(distance: 1) == .previous)
    #expect(tracker.register(distance: 20) == nil)

    tracker.resetGesture()

    #expect(tracker.register(distance: -2) == nil)
    #expect(tracker.register(distance: -4) == .next)
}

@MainActor
@Test func handleScrollWheelCyclesLayoutGroupOnceUntilGestureResets() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var directions: [LayoutGroupCycleDirection] = []

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { AppConfiguration.defaultValue },
        cycleActiveLayoutGroup: { direction in
            directions.append(direction)
            return AppConfiguration.defaultValue
        },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    controller.state.active = true
    controller.state.interactionMode = .layoutSelection
    controller.state.scrollGroupCycleTracker = controller.makeScrollGroupCycleTracker()

    _ = controller.handleScrollWheel(event: try makeScrollEvent(deltaY: 2))
    _ = controller.handleScrollWheel(event: try makeScrollEvent(deltaY: 2))
    _ = controller.handleScrollWheel(event: try makeScrollEvent(deltaY: 2))
    #expect(directions == [.previous])

    _ = controller.handleScrollWheel(event: try makeScrollEvent(deltaY: 10))
    #expect(directions == [.previous])

    controller.state.scrollGroupCycleTracker?.resetGesture()
    _ = controller.handleScrollWheel(event: try makeScrollEvent(deltaY: -6))
    #expect(directions == [.previous, .next])
}

@MainActor
@Test func handleOtherMouseDownMatchesConfiguredSideButtonNumber() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.general.mouseButtonNumber = 5

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let sideButtonDown = try makeOtherMouseEvent(type: .otherMouseDown, buttonNumber: 4)
    let middleButtonDown = try makeOtherMouseEvent(type: .otherMouseDown, buttonNumber: 2)

    let consumedResult = controller.handleOtherMouseDown(event: sideButtonDown, configuration: configuration)
    let passthroughResult = controller.handleOtherMouseDown(event: middleButtonDown, configuration: configuration)

    #expect(consumedResult == nil)
    #expect(controller.state.activeButton == .mouseButton)
    #expect(controller.state.activeOtherMouseButtonNumber == 4)
    #expect(passthroughResult?.takeUnretainedValue() === middleButtonDown)

    controller.resetState()
}

@MainActor
@Test func zeroDelayOtherMouseActivationDoesNotWaitForTimer() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.general.mouseButtonNumber = 5
    configuration.dragTriggers.activationDelayMilliseconds = 0

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    let offscreenPoint = CGPoint(x: -10_000, y: -10_000)
    let sideButtonDown = try makeOtherMouseEvent(
        type: .otherMouseDown,
        buttonNumber: 4,
        point: offscreenPoint
    )

    let result = controller.handleOtherMouseDown(event: sideButtonDown, configuration: configuration)

    #expect(result == nil)
    #expect(controller.state.activationTimer == nil)
    #expect(controller.state.active == false)
    #expect(controller.state.suppressedMouseUpButton == .mouseButton)
}

@MainActor
@Test func handleOtherMouseUpMatchesConfiguredSideButtonNumber() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.general.mouseButtonNumber = 5

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    controller.state.activeButton = .mouseButton
    controller.state.activeOtherMouseButtonNumber = 4
    controller.state.active = true

    let matchingUp = try makeOtherMouseEvent(type: .otherMouseUp, buttonNumber: 4)
    let otherUp = try makeOtherMouseEvent(type: .otherMouseUp, buttonNumber: 2)

    let matchingResult = controller.handleOtherMouseUp(event: matchingUp, configuration: configuration)

    #expect(matchingResult == nil)
    #expect(controller.state.active == false)

    controller.state.activeButton = .mouseButton
    controller.state.activeOtherMouseButtonNumber = 4
    controller.state.active = true

    let passthroughResult = controller.handleOtherMouseUp(event: otherUp, configuration: configuration)

    #expect(passthroughResult?.takeUnretainedValue() === otherUp)

    controller.resetState()
}

@MainActor
@Test func otherMouseActivationWithoutWindowConsumesMatchingMouseUp() async throws {
    let layoutEngine = LayoutEngine()
    let windowController = WindowController(layoutEngine: layoutEngine)
    let overlayController = OverlayController()
    var configuration = AppConfiguration.defaultValue
    configuration.general.mouseButtonNumber = 5

    let controller = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { configuration },
        cycleActiveLayoutGroup: { _ in configuration },
        accessibilityTrustedProvider: { true },
        accessibilityAccessValidator: { true },
        onAccessibilityRevoked: {}
    )

    controller.state.activeButton = .mouseButton
    controller.state.activeOtherMouseButtonNumber = 4
    controller.state.mouseDownPoint = CGPoint(x: -10_000, y: -10_000)

    controller.handleOtherMouseActivation(configuration: configuration)

    #expect(controller.state.active == false)
    #expect(controller.state.activeButton == nil)
    #expect(controller.state.suppressedMouseUpButton == .mouseButton)

    let matchingUp = try makeOtherMouseEvent(type: .otherMouseUp, buttonNumber: 4)
    let result = controller.handleOtherMouseUp(event: matchingUp, configuration: configuration)

    #expect(result == nil)
    #expect(controller.state.suppressedMouseUpButton == nil)
}
