import AppKit
import Foundation
import QuartzCore

@MainActor
final class CALayerOverlayRenderer {
    private static let cursorOffset = CGPoint(x: 10, y: -18)

    private var panel: CALayerOverlayPanel?
    private var screenIdentifier: String?
    private let screenScaleProvider: (NSScreen) -> CGFloat

    var overlayPanel: NSPanel? { panel }

    init(screenScaleProvider: @escaping (NSScreen) -> CGFloat = { $0.backingScaleFactor }) {
        self.screenScaleProvider = screenScaleProvider
    }

    func show(
        on screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState?,
        cursor: OverlayCursorState? = nil
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
                viewBounds: contentView.bounds,
                contentsScale: screenScaleProvider(screen)
            )
        }

        if let cursor {
            addCursorLayer(to: rootLayer, cursor: cursor, screenOrigin: screenOrigin)
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
        viewBounds: CGRect,
        contentsScale: CGFloat
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
        textLayer.contentsScale = contentsScale
        rootLayer.addSublayer(textLayer)
    }

    private func addCursorLayer(
        to rootLayer: CALayer,
        cursor: OverlayCursorState,
        screenOrigin: CGPoint
    ) {
        let point = CGPoint(
            x: cursor.point.x - screenOrigin.x + Self.cursorOffset.x,
            y: cursor.point.y - screenOrigin.y + Self.cursorOffset.y
        )

        switch cursor.mode {
        case .layoutSelection:
            addLayoutCursorLayer(to: rootLayer, at: point)
        case .moveOnly:
            addMoveCursorLayer(to: rootLayer, at: point)
        }
    }

    private func addLayoutCursorLayer(to rootLayer: CALayer, at point: CGPoint) {
        let outerRadius: CGFloat = 8
        let innerRadius: CGFloat = 2.25
        let lineLength: CGFloat = 5
        let gap: CGFloat = 4.5

        addCursorStrokedShapeLayer(
            to: rootLayer,
            path: CGPath(
                ellipseIn: CGRect(
                    x: point.x - outerRadius,
                    y: point.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                ),
                transform: nil
            ),
            outlineWidth: 2,
            fillWidth: 1,
            shadow: true
        )

        let centerRect = CGRect(
            x: point.x - innerRadius,
            y: point.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
        let centerOutlineLayer = CAShapeLayer()
        centerOutlineLayer.path = CGPath(ellipseIn: centerRect, transform: nil)
        centerOutlineLayer.fillColor = cursorOutlineColor
        rootLayer.addSublayer(centerOutlineLayer)

        let centerFillLayer = CAShapeLayer()
        centerFillLayer.path = CGPath(ellipseIn: centerRect.insetBy(dx: 1, dy: 1), transform: nil)
        centerFillLayer.fillColor = cursorFillColor
        rootLayer.addSublayer(centerFillLayer)

        let crosshairPath = CGMutablePath()
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y + gap))
        crosshairPath.addLine(to: CGPoint(x: point.x, y: point.y + gap + lineLength))
        crosshairPath.move(to: CGPoint(x: point.x + gap, y: point.y))
        crosshairPath.addLine(to: CGPoint(x: point.x + gap + lineLength, y: point.y))
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y - gap))
        crosshairPath.addLine(to: CGPoint(x: point.x, y: point.y - gap - lineLength))
        crosshairPath.move(to: CGPoint(x: point.x - gap, y: point.y))
        crosshairPath.addLine(to: CGPoint(x: point.x - gap - lineLength, y: point.y))

        addCursorStrokedShapeLayer(
            to: rootLayer,
            path: crosshairPath,
            outlineWidth: 2.75,
            fillWidth: 1,
            shadow: false
        )
    }

    private func addMoveCursorLayer(to rootLayer: CALayer, at point: CGPoint) {
        let coreRadius: CGFloat = 4
        let arrowInset: CGFloat = 7
        let arrowSize: CGFloat = 4

        addCursorStrokedShapeLayer(
            to: rootLayer,
            path: CGPath(
                ellipseIn: CGRect(
                    x: point.x - coreRadius,
                    y: point.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                ),
                transform: nil
            ),
            outlineWidth: 2,
            fillWidth: 1,
            shadow: true
        )

        addMoveArrowLayer(
            to: rootLayer,
            from: CGPoint(x: point.x, y: point.y + coreRadius + 1.5),
            to: CGPoint(x: point.x, y: point.y + arrowInset),
            direction: .up,
            size: arrowSize
        )
        addMoveArrowLayer(
            to: rootLayer,
            from: CGPoint(x: point.x, y: point.y - coreRadius - 1.5),
            to: CGPoint(x: point.x, y: point.y - arrowInset),
            direction: .down,
            size: arrowSize
        )
        addMoveArrowLayer(
            to: rootLayer,
            from: CGPoint(x: point.x - coreRadius - 1.5, y: point.y),
            to: CGPoint(x: point.x - arrowInset, y: point.y),
            direction: .left,
            size: arrowSize
        )
        addMoveArrowLayer(
            to: rootLayer,
            from: CGPoint(x: point.x + coreRadius + 1.5, y: point.y),
            to: CGPoint(x: point.x + arrowInset, y: point.y),
            direction: .right,
            size: arrowSize
        )
    }

    private func addMoveArrowLayer(
        to rootLayer: CALayer,
        from start: CGPoint,
        to end: CGPoint,
        direction: MoveArrowDirection,
        size: CGFloat
    ) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let tipA: CGPoint
        let tipB: CGPoint
        switch direction {
        case .up:
            tipA = CGPoint(x: end.x - size, y: end.y - size)
            tipB = CGPoint(x: end.x + size, y: end.y - size)
        case .down:
            tipA = CGPoint(x: end.x - size, y: end.y + size)
            tipB = CGPoint(x: end.x + size, y: end.y + size)
        case .left:
            tipA = CGPoint(x: end.x + size, y: end.y - size)
            tipB = CGPoint(x: end.x + size, y: end.y + size)
        case .right:
            tipA = CGPoint(x: end.x - size, y: end.y - size)
            tipB = CGPoint(x: end.x - size, y: end.y + size)
        }

        path.move(to: tipA)
        path.addLine(to: end)
        path.addLine(to: tipB)

        addCursorStrokedShapeLayer(
            to: rootLayer,
            path: path,
            outlineWidth: 2.75,
            fillWidth: 1,
            shadow: false
        )
    }

    private func addCursorStrokedShapeLayer(
        to rootLayer: CALayer,
        path: CGPath,
        outlineWidth: CGFloat,
        fillWidth: CGFloat,
        shadow: Bool
    ) {
        let outlineLayer = CAShapeLayer()
        outlineLayer.path = path
        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = cursorOutlineColor
        outlineLayer.lineWidth = outlineWidth
        outlineLayer.lineCap = .round
        outlineLayer.lineJoin = .round
        if shadow {
            applyCursorShadow(to: outlineLayer)
        }
        rootLayer.addSublayer(outlineLayer)

        let fillLayer = CAShapeLayer()
        fillLayer.path = path
        fillLayer.fillColor = nil
        fillLayer.strokeColor = cursorFillColor
        fillLayer.lineWidth = fillWidth
        fillLayer.lineCap = .round
        fillLayer.lineJoin = .round
        rootLayer.addSublayer(fillLayer)
    }

    private func applyCursorShadow(to layer: CALayer) {
        layer.shadowColor = NSColor.black.withAlphaComponent(0.14).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 1.5
        layer.shadowOffset = CGSize(width: 0, height: -0.5)
    }

    private var cursorFillColor: CGColor {
        NSColor.white.withAlphaComponent(0.96).cgColor
    }

    private var cursorOutlineColor: CGColor {
        NSColor.black.withAlphaComponent(0.9).cgColor
    }

    private func localRect(from globalRect: CGRect, screenOrigin: CGPoint) -> CGRect {
        CGRect(
            x: globalRect.origin.x - screenOrigin.x,
            y: globalRect.origin.y - screenOrigin.y,
            width: globalRect.width,
            height: globalRect.height
        )
    }

    private enum MoveArrowDirection {
        case up
        case down
        case left
        case right
    }
}

@MainActor
private final class CALayerOverlayPanel: NSPanel {
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

        let view = NSView(frame: NSRect(origin: .zero, size: contentRect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
