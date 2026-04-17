import AppKit
import Foundation

@MainActor
final class OverlayController {
    private enum FlashDuration {
        static let seconds: TimeInterval = 0.8
    }

    private struct OverlayContentState {
        let screen: NSScreen
        let slots: [ResolvedTriggerSlot]
        let highlightFrame: CGRect?
        let configuration: AppConfiguration
    }

    private var panel: OverlayPanel?
    private var screenIdentifier: String?
    private var flashGeneration: UInt64 = 0
    private var pendingPostFlashOverlayState: OverlayContentState?

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        configuration: AppConfiguration
    ) {
        cancelPendingFlash()

        guard configuration.appearance.renderTriggerAreas || configuration.appearance.renderWindowHighlight else {
            dismiss()
            return
        }

        showOverlay(screen: screen, slots: slots, highlightFrame: highlightFrame, configuration: configuration)
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
                showOverlay(screen: screen, slots: slots, highlightFrame: frame, configuration: configuration)
            } else {
                dismiss()
            }
            return
        }

        let steadyState = OverlayContentState(
            screen: screen,
            slots: slots,
            highlightFrame: frame,
            configuration: configuration
        )
        pendingPostFlashOverlayState = keepsOverlayVisibleAfterFlash ? steadyState : nil
        showOverlay(
            screen: steadyState.screen,
            slots: steadyState.slots,
            highlightFrame: steadyState.highlightFrame,
            configuration: steadyState.configuration
        )
        panel?.alphaValue = 1.0

        flashGeneration &+= 1
        let expectedGeneration = flashGeneration

        NSAnimationContext.runAnimationGroup { context in
            context.duration = FlashDuration.seconds
            self.panel?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.flashGeneration == expectedGeneration {
                    if let pendingPostFlashOverlayState = self.pendingPostFlashOverlayState {
                        self.panel?.alphaValue = 1.0
                        self.showOverlay(
                            screen: pendingPostFlashOverlayState.screen,
                            slots: pendingPostFlashOverlayState.slots,
                            highlightFrame: pendingPostFlashOverlayState.highlightFrame,
                            configuration: pendingPostFlashOverlayState.configuration
                        )
                        self.pendingPostFlashOverlayState = nil
                    } else {
                        self.dismissPanel()
                    }
                }
            }
        }
    }

    func dismiss() {
        cancelPendingFlash()
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
    }

    private func cancelPendingFlash() {
        flashGeneration &+= 1
        pendingPostFlashOverlayState = nil
        panel?.alphaValue = 1.0
    }

    private func showOverlay(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        configuration: AppConfiguration
    ) {
        let identifier = Geometry.screenIdentifier(for: screen)
        if panel == nil || screenIdentifier != identifier {
            dismissPanel()
            let panel = OverlayPanel(contentRect: screen.frame)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            self.panel = panel
            screenIdentifier = identifier
        } else {
            panel?.setFrame(screen.frame, display: true)
        }

        let overlayView: OverlayView
        if let currentView = panel?.contentView as? OverlayView {
            overlayView = currentView
        } else {
            overlayView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            panel?.contentView = overlayView
        }

        overlayView.frame = NSRect(origin: .zero, size: screen.frame.size)
        overlayView.screenOrigin = screen.frame.origin
        overlayView.resolvedSlots = slots
        overlayView.highlightFrame = highlightFrame
        overlayView.configuration = configuration
        overlayView.needsDisplay = true
    }

    private func dismissPanel() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
        pendingPostFlashOverlayState = nil
    }
}

@MainActor
private final class OverlayPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class OverlayView: NSView {
    var screenOrigin: CGPoint = .zero
    var resolvedSlots: [ResolvedTriggerSlot] = []
    var highlightFrame: CGRect?
    var configuration: AppConfiguration = .defaultValue

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        if configuration.appearance.renderTriggerAreas {
            drawTriggerSlots()
        }

        if configuration.appearance.renderWindowHighlight, let highlightFrame {
            drawHighlight(frame: highlightFrame)
        }
    }

    private func drawTriggerSlots() {
        let color = configuration.appearance.triggerStrokeColor.nsColor
        color.setStroke()

        for slot in resolvedSlots {
            let path = NSBezierPath(roundedRect: localRect(from: slot.triggerFrame), xRadius: 10, yRadius: 10)
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func drawHighlight(frame: CGRect) {
        let color = configuration.appearance.highlightStrokeColor.nsColor
        color.withAlphaComponent(configuration.appearance.highlightFillOpacity).setFill()
        color.setStroke()

        let path = NSBezierPath(roundedRect: localRect(from: frame), xRadius: 10, yRadius: 10)
        path.lineWidth = configuration.appearance.highlightStrokeWidth
        path.fill()
        path.stroke()
    }

    private func localRect(from globalRect: CGRect) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }
}
