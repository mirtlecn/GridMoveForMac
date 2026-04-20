import AppKit
import Foundation

struct OverlayBadgeState {
    let text: String
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
            OverlayBadgeState?
        ) -> Void)?
        var dismissRenderer: (() -> Void)?
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
            return
        }

        renderer?.dismiss()
        renderer = nil
    }
}
