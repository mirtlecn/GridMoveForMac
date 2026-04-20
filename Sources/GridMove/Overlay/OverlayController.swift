import AppKit
import Foundation

struct OverlayBadgeState {
    let text: String
}

@MainActor
final class OverlayController {
    private enum FlashDuration {
        static let seconds: TimeInterval = 0.8
    }

    struct TestHooks {
        var showOverlay: ((
            NSScreen,
            [ResolvedTriggerSlot],
            CGRect?,
            String?,
            AppConfiguration,
            OverlayBadgeState?
        ) -> Void)?
        var dismissRenderer: (() -> Void)?
        var setOverlayAlpha: ((CGFloat) -> Void)?
        var runFlashAnimation: ((
            TimeInterval,
            @escaping () -> Void,
            @escaping @MainActor () -> Void
        ) -> Void)?
    }

    private struct OverlayContentState {
        let screen: NSScreen
        let slots: [ResolvedTriggerSlot]
        let highlightFrame: CGRect?
        let hoveredLayoutID: String?
        let badge: OverlayBadgeState?
        let configuration: AppConfiguration
    }

    private var renderer: CALayerOverlayRenderer?
    private var flashGeneration: UInt64 = 0
    private var isFlashInProgress = false
    private var pendingPostFlashOverlayState: OverlayContentState?
    private let testHooks: TestHooks

    init(testHooks: TestHooks = .init()) {
        self.testHooks = testHooks
    }

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String? = nil
    ) {
        let nextState = makeOverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: hoveredLayoutID,
            configuration: configuration,
            badgeText: badgeText
        )

        if isFlashInProgress {
            pendingPostFlashOverlayState = nextState
            return
        }

        applyOverlayState(nextState)
    }

    func flashHighlight(
        frame: CGRect,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot] = [],
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool = false
    ) {
        stopActiveFlash()

        guard configuration.appearance.renderWindowHighlight else {
            let steadyState = keepsOverlayVisibleAfterFlash ? OverlayContentState(
                screen: screen,
                slots: slots,
                highlightFrame: frame,
                hoveredLayoutID: nil,
                badge: nil,
                configuration: configuration
            ) : nil
            applyOverlayState(steadyState)
            return
        }

        let steadyState = OverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: frame,
            hoveredLayoutID: nil,
            badge: nil,
            configuration: configuration
        )
        pendingPostFlashOverlayState = keepsOverlayVisibleAfterFlash ? steadyState : nil
        showOverlay(
            screen: steadyState.screen,
            slots: steadyState.slots,
            highlightFrame: steadyState.highlightFrame,
            hoveredLayoutID: steadyState.hoveredLayoutID,
            configuration: steadyState.configuration,
            badge: steadyState.badge
        )
        setOverlayAlpha(1.0)

        flashGeneration &+= 1
        isFlashInProgress = true
        let expectedGeneration = flashGeneration

        runFlashAnimation(expectedGeneration: expectedGeneration)
    }

    func dismiss() {
        if isFlashInProgress {
            pendingPostFlashOverlayState = nil
            return
        }

        dismissRenderer()
    }

    private func stopActiveFlash() {
        guard isFlashInProgress else {
            pendingPostFlashOverlayState = nil
            return
        }

        flashGeneration &+= 1
        isFlashInProgress = false
        pendingPostFlashOverlayState = nil
        setOverlayAlpha(1.0)
    }

    private func runFlashAnimation(expectedGeneration: UInt64) {
        let animate: () -> Void = { [weak self] in
            self?.animateOverlayAlpha(to: 0.0)
        }
        let complete: @MainActor () -> Void = { [weak self] in
            self?.finishFlash(expectedGeneration: expectedGeneration)
        }

        if let runFlashAnimation = testHooks.runFlashAnimation {
            runFlashAnimation(FlashDuration.seconds, animate, complete)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = FlashDuration.seconds
            animate()
        } completionHandler: {
            Task { @MainActor in
                complete()
            }
        }
    }

    private func finishFlash(expectedGeneration: UInt64) {
        guard flashGeneration == expectedGeneration else { return }

        isFlashInProgress = false
        let postFlashOverlayState = pendingPostFlashOverlayState
        pendingPostFlashOverlayState = nil

        if postFlashOverlayState != nil {
            setOverlayAlpha(1.0)
        }

        applyOverlayState(postFlashOverlayState)
    }

    private func makeOverlayContentState(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String?
    ) -> OverlayContentState? {
        guard shouldRenderOverlay(configuration: configuration, badgeText: badgeText) else {
            return nil
        }

        return OverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: hoveredLayoutID,
            badge: badgeText.map { OverlayBadgeState(text: $0) },
            configuration: configuration
        )
    }

    private func applyOverlayState(_ overlayContentState: OverlayContentState?) {
        guard let overlayContentState else {
            dismissRenderer()
            return
        }

        showOverlay(
            screen: overlayContentState.screen,
            slots: overlayContentState.slots,
            highlightFrame: overlayContentState.highlightFrame,
            hoveredLayoutID: overlayContentState.hoveredLayoutID,
            configuration: overlayContentState.configuration,
            badge: overlayContentState.badge
        )
    }

    private func setOverlayAlpha(_ alphaValue: CGFloat) {
        if let setOverlayAlpha = testHooks.setOverlayAlpha {
            setOverlayAlpha(alphaValue)
            return
        }

        renderer?.overlayPanel?.alphaValue = alphaValue
    }

    private func animateOverlayAlpha(to alphaValue: CGFloat) {
        if let setOverlayAlpha = testHooks.setOverlayAlpha {
            setOverlayAlpha(alphaValue)
            return
        }

        renderer?.overlayPanel?.animator().alphaValue = alphaValue
    }

    private func shouldRenderOverlay(
        configuration: AppConfiguration,
        badgeText: String?
    ) -> Bool {
        configuration.appearance.renderTriggerAreas
            || configuration.appearance.renderWindowHighlight
            || badgeText != nil
    }

    private func showOverlay(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState? = nil
    ) {
        if let showOverlay = testHooks.showOverlay {
            showOverlay(screen, slots, highlightFrame, hoveredLayoutID, configuration, badge)
            return
        }

        if renderer == nil {
            renderer = CALayerOverlayRenderer()
        }

        renderer?.show(
            on: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: hoveredLayoutID,
            configuration: configuration,
            badge: badge
        )
    }

    private func dismissRenderer() {
        if let dismissRenderer = testHooks.dismissRenderer {
            dismissRenderer()
            pendingPostFlashOverlayState = nil
            return
        }

        renderer?.dismiss()
        renderer = nil
        pendingPostFlashOverlayState = nil
    }
}
