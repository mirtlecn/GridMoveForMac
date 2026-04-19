import AppKit
import Foundation

private struct OverlayBadgeState {
    let text: String
}

struct OverlayCursorState: Equatable {
    let point: CGPoint
    let mode: DragInteractionMode
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

    private var panel: OverlayPanel?
    private var screenIdentifier: String?
    private var cursorPanel: OverlayPanel?
    private var cursorScreenIdentifier: String?
    private var flashGeneration: UInt64 = 0
    private var badgeGeneration: UInt64 = 0
    private var pendingPostFlashOverlayState: OverlayContentState?

    func update(
        screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badgeText: String? = nil,
        cursor: OverlayCursorState? = nil
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
            dismissPanel()
        }

        updateCursorOverlay(screen: screen, cursor: cursor)
    }

    func flashHighlight(
        frame: CGRect,
        screen: NSScreen,
        slots: [ResolvedTriggerSlot] = [],
        configuration: AppConfiguration,
        keepsOverlayVisibleAfterFlash: Bool = false,
        cursor: OverlayCursorState? = nil
    ) {
        cancelPendingFlash()
        updateCursorOverlay(screen: screen, cursor: cursor)

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
                dismissPanel()
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
                            hoveredLayoutID: pendingPostFlashOverlayState.hoveredLayoutID,
                            configuration: pendingPostFlashOverlayState.configuration,
                            badge: pendingPostFlashOverlayState.badge
                        )
                        self.pendingPostFlashOverlayState = nil
                    } else {
                        self.dismissPanel()
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
        keepsOverlayVisibleAfterFlash: Bool,
        cursor: OverlayCursorState?
    ) {
        updateCursorOverlay(screen: screen, cursor: cursor)
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
                    self.dismissPanel()
                }
            }
        }
    }

    func dismiss() {
        cancelPendingFlash()
        dismissPanel()
        dismissCursorPanel()
    }

    private func cancelPendingFlash() {
        flashGeneration &+= 1
        badgeGeneration &+= 1
        pendingPostFlashOverlayState = nil
        panel?.alphaValue = 1.0
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
        overlayView.hoveredLayoutID = hoveredLayoutID
        overlayView.configuration = configuration
        overlayView.badge = badge
        overlayView.cursor = nil
        overlayView.needsDisplay = true
    }

    private func dismissPanel() {
        panel?.orderOut(nil)
        panel = nil
        screenIdentifier = nil
        pendingPostFlashOverlayState = nil
        badgeGeneration &+= 1
    }

    private func updateCursorOverlay(screen: NSScreen, cursor: OverlayCursorState?) {
        guard let cursor else {
            dismissCursorPanel()
            return
        }

        let identifier = Geometry.screenIdentifier(for: screen)
        if cursorPanel == nil || cursorScreenIdentifier != identifier {
            dismissCursorPanel()
            let panel = OverlayPanel(contentRect: screen.frame)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            cursorPanel = panel
            cursorScreenIdentifier = identifier
        } else {
            cursorPanel?.setFrame(screen.frame, display: true)
            cursorPanel?.orderFrontRegardless()
        }

        let overlayView: OverlayView
        if let currentView = cursorPanel?.contentView as? OverlayView {
            overlayView = currentView
        } else {
            overlayView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            cursorPanel?.contentView = overlayView
        }

        overlayView.frame = NSRect(origin: .zero, size: screen.frame.size)
        overlayView.screenOrigin = screen.frame.origin
        overlayView.resolvedSlots = []
        overlayView.highlightFrame = nil
        overlayView.hoveredLayoutID = nil
        overlayView.configuration = .defaultValue
        overlayView.badge = nil
        overlayView.cursor = cursor
        overlayView.needsDisplay = true
    }

    private func dismissCursorPanel() {
        cursorPanel?.orderOut(nil)
        cursorPanel = nil
        cursorScreenIdentifier = nil
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
    private static let cursorOffset = CGPoint(x: 10, y: -18)

    var screenOrigin: CGPoint = .zero
    var resolvedSlots: [ResolvedTriggerSlot] = []
    var highlightFrame: CGRect?
    var hoveredLayoutID: String?
    var configuration: AppConfiguration = .defaultValue
    var badge: OverlayBadgeState?
    var cursor: OverlayCursorState?

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

        if let cursor {
            drawCursor(cursor)
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

    private func drawCursor(_ cursor: OverlayCursorState) {
        let localPoint = CGPoint(
            x: cursor.point.x - screenOrigin.x + Self.cursorOffset.x,
            y: cursor.point.y - screenOrigin.y + Self.cursorOffset.y
        )

        switch cursor.mode {
        case .layoutSelection:
            drawLayoutCursor(at: localPoint)
        case .moveOnly:
            drawMoveCursor(at: localPoint)
        }
    }

    private func drawLayoutCursor(at point: CGPoint) {
        let outerRadius: CGFloat = 8
        let innerRadius: CGFloat = 2.25
        let lineLength: CGFloat = 5
        let gap: CGFloat = 4.5

        let ringPath = NSBezierPath(ovalIn: CGRect(
            x: point.x - outerRadius,
            y: point.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))
        ringPath.lineWidth = 2
        applyCursorShadow()
        cursorOutlineColor.setStroke()
        ringPath.stroke()
        ringPath.lineWidth = 1
        cursorFillColor.setStroke()
        ringPath.stroke()

        let centerRect = CGRect(
            x: point.x - innerRadius,
            y: point.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
        let centerPath = NSBezierPath(ovalIn: centerRect)
        cursorOutlineColor.setFill()
        centerPath.fill()
        cursorFillColor.setFill()
        NSBezierPath(ovalIn: centerRect.insetBy(dx: 1, dy: 1)).fill()

        let crosshairPath = NSBezierPath()
        crosshairPath.lineCapStyle = .round
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y + gap))
        crosshairPath.line(to: CGPoint(x: point.x, y: point.y + gap + lineLength))
        crosshairPath.move(to: CGPoint(x: point.x + gap, y: point.y))
        crosshairPath.line(to: CGPoint(x: point.x + gap + lineLength, y: point.y))
        crosshairPath.move(to: CGPoint(x: point.x, y: point.y - gap))
        crosshairPath.line(to: CGPoint(x: point.x, y: point.y - gap - lineLength))
        crosshairPath.move(to: CGPoint(x: point.x - gap, y: point.y))
        crosshairPath.line(to: CGPoint(x: point.x - gap - lineLength, y: point.y))
        crosshairPath.lineWidth = 2.75
        cursorOutlineColor.setStroke()
        crosshairPath.stroke()
        crosshairPath.lineWidth = 1
        cursorFillColor.setStroke()
        crosshairPath.stroke()
    }

    private func drawMoveCursor(at point: CGPoint) {
        let coreRadius: CGFloat = 4
        let arrowInset: CGFloat = 7
        let arrowSize: CGFloat = 4
        let centerPath = NSBezierPath(ovalIn: CGRect(
            x: point.x - coreRadius,
            y: point.y - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        ))
        applyCursorShadow()
        centerPath.lineWidth = 2
        cursorOutlineColor.setStroke()
        centerPath.stroke()
        centerPath.lineWidth = 1
        cursorFillColor.setStroke()
        centerPath.stroke()

        drawMoveArrow(
            from: CGPoint(x: point.x, y: point.y + coreRadius + 1.5),
            to: CGPoint(x: point.x, y: point.y + arrowInset),
            direction: .up,
            size: arrowSize
        )
        drawMoveArrow(
            from: CGPoint(x: point.x, y: point.y - coreRadius - 1.5),
            to: CGPoint(x: point.x, y: point.y - arrowInset),
            direction: .down,
            size: arrowSize
        )
        drawMoveArrow(
            from: CGPoint(x: point.x - coreRadius - 1.5, y: point.y),
            to: CGPoint(x: point.x - arrowInset, y: point.y),
            direction: .left,
            size: arrowSize
        )
        drawMoveArrow(
            from: CGPoint(x: point.x + coreRadius + 1.5, y: point.y),
            to: CGPoint(x: point.x + arrowInset, y: point.y),
            direction: .right,
            size: arrowSize
        )
    }

    private func drawMoveArrow(from start: CGPoint, to end: CGPoint, direction: MoveArrowDirection, size: CGFloat) {
        let shaftPath = NSBezierPath()
        shaftPath.lineCapStyle = .round
        shaftPath.move(to: start)
        shaftPath.line(to: end)
        shaftPath.lineWidth = 2.75
        cursorOutlineColor.setStroke()
        shaftPath.stroke()
        shaftPath.lineWidth = 1
        cursorFillColor.setStroke()
        shaftPath.stroke()

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

        let headPath = NSBezierPath()
        headPath.lineCapStyle = .round
        headPath.lineJoinStyle = .round
        headPath.move(to: tipA)
        headPath.line(to: end)
        headPath.line(to: tipB)
        headPath.lineWidth = 2.75
        cursorOutlineColor.setStroke()
        headPath.stroke()
        headPath.lineWidth = 1
        cursorFillColor.setStroke()
        headPath.stroke()
    }

    private func applyCursorShadow() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowBlurRadius = 1.5
        shadow.shadowOffset = CGSize(width: 0, height: -0.5)
        shadow.set()
    }

    private var cursorFillColor: NSColor {
        NSColor.white.withAlphaComponent(0.96)
    }

    private var cursorOutlineColor: NSColor {
        NSColor.black.withAlphaComponent(0.9)
    }

    private enum MoveArrowDirection {
        case up
        case down
        case left
        case right
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
