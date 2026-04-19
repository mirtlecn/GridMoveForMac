import AppKit
import Foundation
import QuartzCore

@MainActor
final class CALayerOverlayRenderer: OverlayRenderer {
    private var panel: CALayerOverlayPanel?
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
            let newPanel = CALayerOverlayPanel(contentRect: screen.frame)
            newPanel.setFrame(screen.frame, display: true)
            newPanel.orderFrontRegardless()
            panel = newPanel
            screenIdentifier = identifier
        } else {
            panel?.setFrame(screen.frame, display: true)
        }

        guard let contentView = panel?.contentView else { return }
        contentView.frame = NSRect(origin: .zero, size: screen.frame.size)

        let screenOrigin = screen.frame.origin
        let appearance = configuration.appearance

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if !contentView.wantsLayer {
            contentView.wantsLayer = true
        }
        guard let rootLayer = contentView.layer else {
            CATransaction.commit()
            return
        }

        removeAllSublayers(from: rootLayer)

        if appearance.renderTriggerAreas {
            addTriggerSlotLayers(
                to: rootLayer,
                slots: slots,
                hoveredLayoutID: hoveredLayoutID,
                appearance: appearance,
                screenOrigin: screenOrigin
            )
        }

        if appearance.renderWindowHighlight, let highlightFrame {
            addHighlightLayer(
                to: rootLayer,
                frame: highlightFrame,
                appearance: appearance,
                screenOrigin: screenOrigin
            )
        }

        if let badge {
            addBadgeLayer(
                to: rootLayer,
                text: badge.text,
                highlightFrame: highlightFrame,
                screenOrigin: screenOrigin,
                viewBounds: contentView.bounds
            )
        }

        CATransaction.commit()
    }

    func dismiss() {
        dismissInternal()
    }

    private func dismissInternal() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
    }

    private func removeAllSublayers(from layer: CALayer) {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    private func addTriggerSlotLayers(
        to rootLayer: CALayer,
        slots: [ResolvedTriggerSlot],
        hoveredLayoutID: String?,
        appearance: AppearanceSettings,
        screenOrigin: CGPoint
    ) {
        let visibleSlots: [ResolvedTriggerSlot] = switch appearance.triggerHighlightMode {
        case .all:
            slots
        case .current:
            slots.filter { $0.layoutID == hoveredLayoutID }
        case .none:
            []
        }

        let color = appearance.triggerStrokeColor.nsColor
        let fillColor = color.withAlphaComponent(appearance.triggerFillOpacity).cgColor
        let strokeWidth = SettingsPreviewSupport.triggerStrokeWidth(for: appearance)
        let strokeColor = strokeWidth != nil ? color.cgColor : nil
        let cornerRadius: CGFloat = 10

        for slot in visibleSlots {
            for hitTestFrame in slot.hitTestFrames {
                let localFrame = localRect(from: hitTestFrame, screenOrigin: screenOrigin)
                let shapeLayer = CAShapeLayer()
                shapeLayer.frame = localFrame
                shapeLayer.path = CGPath(
                    roundedRect: CGRect(origin: .zero, size: localFrame.size),
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
                shapeLayer.fillColor = fillColor
                if let strokeColor, let strokeWidth {
                    shapeLayer.strokeColor = strokeColor
                    shapeLayer.lineWidth = strokeWidth
                }
                rootLayer.addSublayer(shapeLayer)
            }
        }
    }

    private func addHighlightLayer(
        to rootLayer: CALayer,
        frame: CGRect,
        appearance: AppearanceSettings,
        screenOrigin: CGPoint
    ) {
        let localFrame = localRect(from: frame, screenOrigin: screenOrigin)
        let color = appearance.highlightStrokeColor.nsColor
        let cornerRadius: CGFloat = 10

        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = localFrame
        shapeLayer.path = CGPath(
            roundedRect: CGRect(origin: .zero, size: localFrame.size),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        shapeLayer.fillColor = color.withAlphaComponent(appearance.highlightFillOpacity).cgColor

        if let strokeWidth = SettingsPreviewSupport.windowHighlightStrokeWidth(for: appearance) {
            shapeLayer.strokeColor = color.cgColor
            shapeLayer.lineWidth = strokeWidth
        }

        rootLayer.addSublayer(shapeLayer)
    }

    private func addBadgeLayer(
        to rootLayer: CALayer,
        text: String,
        highlightFrame: CGRect?,
        screenOrigin: CGPoint,
        viewBounds: CGRect
    ) {
        let targetRect: CGRect
        if let highlightFrame {
            targetRect = localRect(from: highlightFrame, screenOrigin: screenOrigin)
        } else {
            targetRect = viewBounds.insetBy(dx: 48, dy: 48)
        }

        let font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = NSAttributedString(string: text, attributes: textAttributes).size()
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 10
        let badgeSize = CGSize(
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )
        let badgeOrigin = CGPoint(
            x: targetRect.midX - badgeSize.width / 2,
            y: targetRect.midY - badgeSize.height / 2
        )
        let badgeFrame = CGRect(origin: badgeOrigin, size: badgeSize)

        let backgroundLayer = CAShapeLayer()
        backgroundLayer.frame = badgeFrame
        backgroundLayer.path = CGPath(
            roundedRect: CGRect(origin: .zero, size: badgeSize),
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
        backgroundLayer.fillColor = NSColor.black.withAlphaComponent(0.72).cgColor
        rootLayer.addSublayer(backgroundLayer)

        let textLayer = CATextLayer()
        textLayer.frame = CGRect(
            x: badgeFrame.minX + horizontalPadding,
            y: badgeFrame.minY + verticalPadding,
            width: textSize.width,
            height: textSize.height
        )
        textLayer.string = NSAttributedString(string: text, attributes: textAttributes)
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        rootLayer.addSublayer(textLayer)
    }

    private func localRect(from globalRect: CGRect, screenOrigin: CGPoint) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }
}

@MainActor
private final class CALayerOverlayPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .nonretained,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let view = NSView(frame: NSRect(origin: .zero, size: contentRect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
