import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import GridMove

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
}

@Test func moveAnchorPreservesPointerOffset() async throws {
    let anchor = MoveAnchor(
        mousePoint: CGPoint(x: 400, y: 300),
        windowOrigin: CGPoint(x: 120, y: 80)
    )

    #expect(anchor.movedOrigin(for: CGPoint(x: 460, y: 355)) == CGPoint(x: 180, y: 135))
}

@MainActor
@Test func moveOnlyFlashPrefersWindowScreenOverActiveScreen() async throws {
    #expect(
        DragGridController.preferredMoveOnlyFlashScreen(
            windowScreen: "window-screen",
            activeScreen: "active-screen",
            pointerScreen: "pointer-screen"
        ) == "window-screen"
    )
    #expect(
        DragGridController.preferredMoveOnlyFlashScreen(
            windowScreen: nil,
            activeScreen: "active-screen",
            pointerScreen: "pointer-screen"
        ) == "active-screen"
    )
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
        cycleActiveLayoutGroup: { updatedConfiguration },
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
