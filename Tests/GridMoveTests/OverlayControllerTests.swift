import AppKit
import Testing
@testable import GridMove

@MainActor
private final class OverlayControllerRecorder {
    enum Event: Equatable {
        case showHighlight
        case showLayout
        case dismiss
        case alpha(CGFloat)
    }

    var events: [Event] = []
    var flashCompletion: (@MainActor () -> Void)?
}

@MainActor
private func makeOverlayController(
    recorder: OverlayControllerRecorder
) -> OverlayController {
    OverlayController(
        testHooks: .init(
            showOverlay: { _, slots, highlightFrame, _, _, _ in
                if highlightFrame != nil {
                    recorder.events.append(.showHighlight)
                } else if slots.isEmpty {
                    recorder.events.append(.showHighlight)
                } else {
                    recorder.events.append(.showLayout)
                }
            },
            dismissRenderer: {
                recorder.events.append(.dismiss)
            },
            setOverlayAlpha: { alphaValue in
                recorder.events.append(.alpha(alphaValue))
            },
            runFlashAnimation: { _, animate, completion in
                animate()
                recorder.flashCompletion = completion
            }
        )
    )
}

private func primaryScreen() throws -> NSScreen {
    try #require(NSScreen.screens.first)
}

private func makeTriggerSlot() -> ResolvedTriggerSlot {
    ResolvedTriggerSlot(
        layoutID: "left",
        triggerFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
        hitTestFrames: [CGRect(x: 0, y: 0, width: 100, height: 100)],
        targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
}

@MainActor
@Test func dismissWaitsForMoveModeFlashToFinish() throws {
    let recorder = OverlayControllerRecorder()
    let controller = makeOverlayController(recorder: recorder)
    let screen = try primaryScreen()

    controller.flashHighlight(
        frame: CGRect(x: 20, y: 20, width: 120, height: 80),
        screen: screen,
        configuration: .defaultValue,
        keepsOverlayVisibleAfterFlash: false
    )

    #expect(recorder.events == [.showHighlight, .alpha(1.0), .alpha(0.0)])

    controller.dismiss()
    #expect(recorder.events == [.showHighlight, .alpha(1.0), .alpha(0.0)])

    let flashCompletion = try #require(recorder.flashCompletion)
    flashCompletion()

    #expect(recorder.events == [.showHighlight, .alpha(1.0), .alpha(0.0), .dismiss])
}

@MainActor
@Test func dismissClearsDeferredLayoutOverlayDuringMoveModeFlash() throws {
    let recorder = OverlayControllerRecorder()
    let controller = makeOverlayController(recorder: recorder)
    let screen = try primaryScreen()

    controller.flashHighlight(
        frame: CGRect(x: 20, y: 20, width: 120, height: 80),
        screen: screen,
        configuration: .defaultValue,
        keepsOverlayVisibleAfterFlash: false
    )

    var layoutConfiguration = AppConfiguration.defaultValue
    layoutConfiguration.appearance.triggerHighlightMode = .all
    layoutConfiguration.appearance.renderWindowHighlight = false

    controller.update(
        screen: screen,
        slots: [makeTriggerSlot()],
        highlightFrame: nil,
        hoveredLayoutID: "left",
        configuration: layoutConfiguration
    )
    controller.dismiss()

    #expect(recorder.events == [.showHighlight, .alpha(1.0), .alpha(0.0)])

    let flashCompletion = try #require(recorder.flashCompletion)
    flashCompletion()

    #expect(recorder.events == [.showHighlight, .alpha(1.0), .alpha(0.0), .dismiss])
}
