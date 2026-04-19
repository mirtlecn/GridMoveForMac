import AppKit
import Foundation

@MainActor
final class LegacyOverlayRenderer: OverlayRenderer {
    private var panel: LegacyOverlayPanel?
    private var screenIdentifier: String?

    var overlayPanel: NSPanel? { panel }

    func show(
        on screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState?
    ) {
        let identifier = Geometry.screenIdentifier(for: screen)
        if panel == nil || screenIdentifier != identifier {
            dismissInternal()
            let newPanel = LegacyOverlayPanel(contentRect: screen.frame)
            newPanel.setFrame(screen.frame, display: true)
            newPanel.orderFrontRegardless()
            panel = newPanel
            screenIdentifier = identifier
        } else {
            panel?.setFrame(screen.frame, display: true)
        }

        let overlayView: LegacyOverlayView
        if let currentView = panel?.contentView as? LegacyOverlayView {
            overlayView = currentView
        } else {
            overlayView = LegacyOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            panel?.contentView = overlayView
        }

        overlayView.frame = NSRect(origin: .zero, size: screen.frame.size)
        overlayView.screenOrigin = screen.frame.origin
        overlayView.resolvedSlots = slots
        overlayView.highlightFrame = highlightFrame
        overlayView.hoveredLayoutID = hoveredLayoutID
        overlayView.configuration = configuration
        overlayView.badge = badge
        overlayView.needsDisplay = true
    }

    func dismiss() {
        dismissInternal()
    }

    private func dismissInternal() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
    }
}

@MainActor
private final class LegacyOverlayPanel: NSPanel {
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
private final class LegacyOverlayView: NSView {
    var screenOrigin: CGPoint = .zero
    var resolvedSlots: [ResolvedTriggerSlot] = []
    var highlightFrame: CGRect?
    var hoveredLayoutID: String?
    var configuration: AppConfiguration = .defaultValue
    var badge: OverlayBadgeState?

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

        if let badge {
            drawBadge(text: badge.text, highlightedFrame: highlightFrame)
        }
    }

    private func drawTriggerSlots() {
        let visibleSlots: [ResolvedTriggerSlot] = switch configuration.appearance.triggerHighlightMode {
        case .all:
            resolvedSlots
        case .current:
            resolvedSlots.filter { $0.layoutID == hoveredLayoutID }
        case .none:
            []
        }

        for slot in visibleSlots {
            for hitTestFrame in slot.hitTestFrames {
                SettingsPreviewSupport.drawTriggerRegion(
                    rect: localRect(from: hitTestFrame),
                    appearance: configuration.appearance,
                    cornerRadius: 10
                )
            }
        }
    }

    private func drawHighlight(frame: CGRect) {
        SettingsPreviewSupport.drawWindowHighlight(
            rect: localRect(from: frame),
            appearance: configuration.appearance,
            cornerRadius: 10
        )
    }

    private func drawBadge(text: String, highlightedFrame: CGRect?) {
        let targetRect = highlightedFrame.map(localRect(from:)) ?? bounds.insetBy(dx: 48, dy: 48)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let attributedText = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = attributedText.size()
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10
        let badgeRect = CGRect(
            x: targetRect.midX - ((textSize.width + horizontalPadding * 2) / 2),
            y: targetRect.midY - ((textSize.height + verticalPadding * 2) / 2),
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )

        let backgroundPath = NSBezierPath(roundedRect: badgeRect, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.72).setFill()
        backgroundPath.fill()

        let textRect = CGRect(
            x: badgeRect.minX + horizontalPadding,
            y: badgeRect.minY + verticalPadding,
            width: textSize.width,
            height: textSize.height
        )
        attributedText.draw(in: textRect)
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
