import AppKit
import Foundation

@MainActor
final class OverlayController {
    private var panel: OverlayPanel?
    private var screenIdentifier: String?

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        configuration: AppConfiguration
    ) {
        guard configuration.appearance.renderTriggerAreas || configuration.appearance.renderWindowHighlight else {
            dismiss()
            return
        }

        let identifier = Geometry.screenIdentifier(for: screen)
        if panel == nil || screenIdentifier != identifier {
            dismiss()
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

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
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
