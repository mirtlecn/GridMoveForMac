import AppKit
import Foundation

struct OverlayBadgeState {
    let text: String
}

struct OverlayCursorState: Equatable {
    let point: CGPoint
    let mode: DragInteractionMode
}

@MainActor
final class OverlayController {
    struct TestHooks {
        var showOverlay: ((
            NSScreen,
            [ResolvedTriggerSlot],
            CGRect?,
            String?,
            AppConfiguration,
            OverlayBadgeState?,
            OverlayCursorState?
        ) -> Void)?
        var dismissRenderer: (() -> Void)?
    }

    private struct OverlayContentState {
        let screen: NSScreen
        let slots: [ResolvedTriggerSlot]
        let highlightFrame: CGRect?
        let hoveredLayoutID: String?
        let badge: OverlayBadgeState?
        let cursor: OverlayCursorState?
        let configuration: AppConfiguration
    }

    private var renderer: CALayerOverlayRenderer?
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
        badgeText: String? = nil,
        cursor: OverlayCursorState? = nil
    ) {
        let nextState = makeOverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: hoveredLayoutID,
            configuration: configuration,
            badgeText: badgeText,
            cursor: cursor
        )
        applyOverlayState(nextState)
    }

    func dismiss() {
        dismissRenderer()
    }

    private func makeOverlayContentState(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String?,
        cursor: OverlayCursorState?
    ) -> OverlayContentState? {
        guard shouldRenderOverlay(configuration: configuration, badgeText: badgeText, cursor: cursor) else {
            return nil
        }

        return OverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: hoveredLayoutID,
            badge: badgeText.map { OverlayBadgeState(text: $0) },
            cursor: cursor,
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
            badge: overlayContentState.badge,
            cursor: overlayContentState.cursor
        )
    }

    private func shouldRenderOverlay(
        configuration: AppConfiguration,
        badgeText: String?,
        cursor: OverlayCursorState?
    ) -> Bool {
        configuration.appearance.renderTriggerAreas
            || configuration.appearance.renderWindowHighlight
            || badgeText != nil
            || cursor != nil
    }

    private func showOverlay(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState? = nil,
        cursor: OverlayCursorState? = nil
    ) {
        if let showOverlay = testHooks.showOverlay {
            showOverlay(screen, slots, highlightFrame, hoveredLayoutID, configuration, badge, cursor)
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
            badge: badge,
            cursor: cursor
        )
    }

    private func dismissRenderer() {
        if let dismissRenderer = testHooks.dismissRenderer {
            dismissRenderer()
            return
        }

        renderer?.dismiss()
        renderer = nil
    }
}
