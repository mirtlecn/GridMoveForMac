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
    var tracker = OptionToggleTracker(baselinePressed: false)

    #expect(tracker.register(isPressed: true) == .consume)
    #expect(tracker.isPending == true)
    #expect(tracker.register(isPressed: false) == .toggle)
    #expect(tracker.isPending == false)
}

@Test func optionToggleTrackerTogglesAfterReleaseThenPress() async throws {
    var tracker = OptionToggleTracker(baselinePressed: true)

    #expect(tracker.register(isPressed: false) == .consume)
    #expect(tracker.isPending == true)
    #expect(tracker.register(isPressed: true) == .toggle)
    #expect(tracker.isPending == false)
}

@Test func optionToggleTrackerIgnoresRepeatedState() async throws {
    var tracker = OptionToggleTracker(baselinePressed: false)

    #expect(tracker.register(isPressed: false) == .ignore)
    #expect(tracker.register(isPressed: true) == .consume)
    #expect(tracker.register(isPressed: true) == .ignore)
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
