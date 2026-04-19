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
    private var badgeGeneration: UInt64 = 0
    private var pendingPostFlashOverlayState: OverlayContentState?

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String? = nil
    ) {
        cancelPendingFlash()

        if shouldRenderOverlay(configuration: configuration, badgeText: badgeText) {
            showOverlay(
                screen: screen,
                slots: slots,
                highlightFrame: highlightFrame,
                hoveredLayoutID: hoveredLayoutID,
                configuration: configuration,
                badge: badgeText.map { OverlayBadgeState(text: $0) }
            )
        } else {
            dismissRenderer()
        }
    }

    func flashHighlight(
        frame: CGRect,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot] = [],
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool = false
    ) {
        cancelPendingFlash()

        guard configuration.appearance.renderWindowHighlight else {
            if keepsOverlayVisibleAfterFlash {
                showOverlay(
                    screen: screen,
                    slots: slots,
                    highlightFrame: frame,
                    hoveredLayoutID: nil,
                    configuration: configuration
                )
            } else {
                dismissRenderer()
            }
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
        renderer?.overlayPanel?.alphaValue = 1.0

        flashGeneration &+= 1
        let expectedGeneration = flashGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = FlashDuration.seconds
            self.renderer?.overlayPanel?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.flashGeneration == expectedGeneration {
                    if let pendingPostFlashOverlayState = self.pendingPostFlashOverlayState {
                        self.renderer?.overlayPanel?.alphaValue = 1.0
                        self.showOverlay(
                            screen: pendingPostFlashOverlayState.screen,
                            slots: pendingPostFlashOverlayState.slots,
                            highlightFrame: pendingPostFlashOverlayState.highlightFrame,
                            hoveredLayoutID: pendingPostFlashOverlayState.hoveredLayoutID,
                            configuration: pendingPostFlashOverlayState.configuration,
                            badge: pendingPostFlashOverlayState.badge
                        )
                        self.pendingPostFlashOverlayState = nil
                    } else {
                        self.dismissRenderer()
                    }
                }
            }
        }
    }

    func flashGroupLabel(
        text: String,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool
    ) {
        showOverlay(
            screen: screen,
            slots: slots,
            highlightFrame: highlightFrame,
            hoveredLayoutID: nil,
            configuration: configuration,
            badge: OverlayBadgeState(text: text)
        )

        badgeGeneration &+= 1
        let expectedGeneration = badgeGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + FlashDuration.seconds) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                guard self.badgeGeneration == expectedGeneration else { return }

                if keepsOverlayVisibleAfterFlash {
                    self.showOverlay(
                        screen: screen,
                        slots: slots,
                        highlightFrame: highlightFrame,
                        hoveredLayoutID: nil,
                        configuration: configuration,
                        badge: nil
                    )
                } else {
                    self.dismissRenderer()
                }
            }
        }
    }

    func dismiss() {
        cancelPendingFlash()
        dismissRenderer()
    }

    private func cancelPendingFlash() {
        flashGeneration &+= 1
        badgeGeneration &+= 1
        pendingPostFlashOverlayState = nil
        renderer?.overlayPanel?.alphaValue = 1.0
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
        renderer?.dismiss()
        renderer = nil
        pendingPostFlashOverlayState = nil
        badgeGeneration &+= 1
    }
}
